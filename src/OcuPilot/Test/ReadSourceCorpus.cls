/// <p>The one corpus both engines of the <code>read.source</code> type, <code>forEach</code>,
/// <code>query</code> and <code>parts</code> grammar
/// run (AD-36): <method>OcuPilot.Screen.Registry.ReadProblem</method> in
/// <class>OcuPilot.Test.ReadTool</class> and <code>readProblem</code> in
/// <file>ui/tools/screen-mirror.test.mjs</file>, which reads this block off disk. Each case replaces
/// <code>declaration.read.source</code> with its own <code>source</code>, sets
/// <code>declaration.read.criteria</code> when it carries one, sets <code>declaration.parentScope</code>
/// when it carries one (Story 6.7's route-id GET cases), sets <code>declaration.read.fields</code>,
/// <code>filter</code>, <code>sort</code>, <code>table</code> and <code>context</code> when it carries
/// them (Story 6.9's parts cases, whose fields cannot start with the shared declaration's own), and
/// names the exact sentence both engines return, or <code>null</code> for a sound shape.</p>
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
    {"name": "a type outside the five", "source": {"port": "admin", "endpoint": "Security.OAuth2.Server", "type": "POST"}, "expected": "read.source.type 'POST' is not 'LIST', 'GET', 'UPCOMING', 'HISTORY' or 'VOLUMELIST'"},
    {"name": "a type is spelled exactly", "source": {"port": "admin", "endpoint": "Security.OAuth2.Server", "type": "get"}, "expected": "read.source.type 'get' is not 'LIST', 'GET', 'UPCOMING', 'HISTORY' or 'VOLUMELIST'"},
    {"name": "a detail type is not a source type", "source": {"port": "admin", "endpoint": "Security.X509Credential", "type": "CERTINFO"}, "expected": "read.source.type 'CERTINFO' is not 'LIST', 'GET', 'UPCOMING', 'HISTORY' or 'VOLUMELIST'"},
    {"name": "a missing type", "source": {"port": "admin", "endpoint": "Security.OAuth2.Server"}, "expected": "read.source.type '' is not 'LIST', 'GET', 'UPCOMING', 'HISTORY' or 'VOLUMELIST'"},
    {"name": "a GET on the management port", "source": {"port": "mgmnt", "endpoint": "Applications", "type": "GET"}, "expected": "read.source.type 'GET' is declared on a 'mgmnt' source, and a single-object read issues an admin endpoint's GET (AD-36)"},
    {"name": "a GET on a state source", "source": {"port": "state", "endpoint": "Agent", "type": "GET"}, "expected": "read.source.type 'GET' is declared on a 'state' source, and a single-object read issues an admin endpoint's GET (AD-36)"},
    {"name": "a GET with a detail call and no criteria", "source": {"port": "admin", "endpoint": "Security.OAuth2.Server", "type": "GET", "rowGet": {"key": "Name", "param": "name", "fields": ["IssuerEndpoint"], "derived": []}}, "expected": "read.source.rowGet is declared on a GET source with no read.criteria, and a single-object read issues a detail call only alongside its one parent-scoped route-id criterion (AD-36, Story 6.7)"},
    {"name": "a GET with a parent list", "source": {"port": "admin", "endpoint": "Security.OAuth2.Server", "type": "GET", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": []}}, "expected": "read.source.forEach is declared on a GET source, which reads one object and lists no parents (AD-36)"},
    {"name": "a GET with server criteria but no parentScope", "source": {"port": "admin", "endpoint": "Security.OAuth2.Server", "type": "GET"}, "criteria": {"fields": [{"param": "serverId", "labelKey": "tableColumnName", "kind": "text", "maxLength": 64}]}, "expected": "read.criteria is declared on a GET source with no parentScope, and a single-object read takes its one criterion from the route id only when parent-scoped (AD-36, Story 6.7)"},
    {"name": "a parent-scoped GET with its one route-id criterion is sound (Story 6.7)", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "GET"}, "criteria": {"fields": [{"param": "taskId", "labelKey": "taskHistoryColumnTaskId", "kind": "text", "maxLength": 10, "vendorParam": "id"}]}, "parentScope": "tasks/schedule", "expected": null},
    {"name": "a parent-scoped GET's rowGet keyed by that same criterion param is sound (Story 6.7)", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "GET", "rowGet": {"key": "taskId", "param": "id", "type": "INFO", "fields": ["IssuerEndpoint"], "derived": []}}, "criteria": {"fields": [{"param": "taskId", "labelKey": "taskHistoryColumnTaskId", "kind": "text", "maxLength": 10, "vendorParam": "id"}]}, "parentScope": "tasks/schedule", "expected": null},
    {"name": "a LIST with one criterion keys its rowGet by a read field, not the criterion (Story 6.7)", "source": {"port": "admin", "endpoint": "Security.OAuth2.Server", "type": "LIST", "rowGet": {"key": "Name", "param": "name", "fields": ["IssuerEndpoint"], "derived": []}}, "criteria": {"fields": [{"param": "serverId", "labelKey": "tableColumnName", "kind": "text", "maxLength": 64}]}, "expected": null},
    {"name": "a parent-scoped GET's rowGet key must equal the criterion's own param (Story 6.7)", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "GET", "rowGet": {"key": "wrongKey", "param": "id", "type": "INFO", "fields": ["IssuerEndpoint"], "derived": []}}, "criteria": {"fields": [{"param": "taskId", "labelKey": "taskHistoryColumnTaskId", "kind": "text", "maxLength": 10, "vendorParam": "id"}]}, "parentScope": "tasks/schedule", "expected": "read.source.rowGet.key 'wrongKey' must equal the read's one route-id criterion param (AD-36, Story 6.7)"},
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
    {"name": "a fixed query beside a parent list is sound", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "query": {"fixed": "1"}, "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": []}}, "expected": null},
    {"name": "a param a fixed query also names, case-folded", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "query": {"ServerID": "1"}, "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": []}}, "expected": "read.source.forEach.param 'serverId' is also a read.source.query key, which each child list would overwrite (AD-36)"},
    {"name": "a param that is not a name", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "server-id", "fields": []}}, "expected": "read.source.forEach.param 'server-id' is not a query parameter name"},
    {"name": "fields that are not an array", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": "ID"}}, "expected": "read.source.forEach.fields is not an array of parent fields"},
    {"name": "a fields entry that is not an object", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": ["ServerDefinitionID"]}}, "expected": "read.source.forEach.fields entry #1 is not an object declaring its field and from"},
    {"name": "a fields entry with an unknown key", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": [{"field": "ServerDefinitionID", "from": "ID", "type": "number"}]}}, "expected": "read.source.forEach.fields entry #1 declares the unknown key 'type'"},
    {"name": "a field outside the read's fields", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": [{"field": "ID", "from": "ID"}]}}, "expected": "read.source.forEach.fields entry #1 field 'ID' is not one of read.fields"},
    {"name": "a repeated field", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": [{"field": "IssuerEndpoint", "from": "IssuerEndpoint"}, {"field": "IssuerEndpoint", "from": "ID"}]}}, "expected": "read.source.forEach.fields entry #2 names the field 'IssuerEndpoint' twice"},
    {"name": "an empty from", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": [{"field": "ServerDefinitionID", "from": ""}]}}, "expected": "read.source.forEach.fields entry #1 from is empty, and a parent field is copied from a named key of the parent"},
    {"name": "a missing from", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": [{"field": "ServerDefinitionID"}]}}, "expected": "read.source.forEach.fields entry #1 from is empty, and a parent field is copied from a named key of the parent"},
    {"name": "an UPCOMING source with criteria is sound", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "UPCOMING"}, "criteria": {"fields": [{"param": "hoursOffset", "labelKey": "tableColumnName", "kind": "choice", "maxLength": 3, "options": ["1", "24"]}]}, "expected": null},
    {"name": "the type UPCOMING is spelled exactly", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "Upcoming"}, "expected": "read.source.type 'Upcoming' is not 'LIST', 'GET', 'UPCOMING', 'HISTORY' or 'VOLUMELIST'"},
    {"name": "an UPCOMING source on the management port", "source": {"port": "mgmnt", "endpoint": "Applications", "type": "UPCOMING"}, "expected": "read.source.type 'UPCOMING' is declared on a 'mgmnt' source, and a list-shaped request type other than LIST issues an admin endpoint (AD-36)"},
    {"name": "an UPCOMING source on a state source", "source": {"port": "state", "endpoint": "Agent", "type": "UPCOMING"}, "expected": "read.source.type 'UPCOMING' is declared on a 'state' source, and a list-shaped request type other than LIST issues an admin endpoint (AD-36)"},
    {"name": "an UPCOMING source with a detail call", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "UPCOMING", "rowGet": {"key": "Name", "param": "id", "type": "INFO", "fields": ["IssuerEndpoint"], "derived": []}}, "expected": "read.source.rowGet is declared on an UPCOMING source, whose rows are occurrences with no detail call to issue (AD-36)"},
    {"name": "an UPCOMING source with a parent list", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "UPCOMING", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": []}}, "expected": "read.source.forEach is declared on an UPCOMING source, which lists no parents (AD-36)"},
    {"name": "a HISTORY source with criteria is sound", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "HISTORY"}, "criteria": {"fields": [{"param": "search", "labelKey": "tableColumnName", "kind": "text", "maxLength": 100, "vendorParam": "filter"}]}, "expected": null},
    {"name": "the type HISTORY is spelled exactly", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "History"}, "expected": "read.source.type 'History' is not 'LIST', 'GET', 'UPCOMING', 'HISTORY' or 'VOLUMELIST'"},
    {"name": "a HISTORY source on the management port", "source": {"port": "mgmnt", "endpoint": "Applications", "type": "HISTORY"}, "expected": "read.source.type 'HISTORY' is declared on a 'mgmnt' source, and a list-shaped request type other than LIST issues an admin endpoint (AD-36)"},
    {"name": "a HISTORY source on a state source", "source": {"port": "state", "endpoint": "Agent", "type": "HISTORY"}, "expected": "read.source.type 'HISTORY' is declared on a 'state' source, and a list-shaped request type other than LIST issues an admin endpoint (AD-36)"},
    {"name": "a HISTORY source with a detail call", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "HISTORY", "rowGet": {"key": "TaskId", "param": "id", "fields": ["Routine"], "derived": []}}, "expected": "read.source.rowGet is declared on a HISTORY source, whose rows are task runs with no detail call to issue (AD-36)"},
    {"name": "a HISTORY source with a parent list", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "HISTORY", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": []}}, "expected": "read.source.forEach is declared on a HISTORY source, which lists no parents (AD-36)"},
    {"name": "a fixed query is sound", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "LIST", "query": {"onDemand": "1"}}, "expected": null},
    {"name": "a fixed query beside criteria of other names is sound", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "UPCOMING", "query": {"filter2": "a"}}, "criteria": {"fields": [{"param": "hoursOffset", "labelKey": "tableColumnName", "kind": "text", "maxLength": 3}]}, "expected": null},
    {"name": "a value of fifty characters is sound", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "LIST", "query": {"onDemand": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}}, "expected": null},
    {"name": "a null query fixes nothing", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "LIST", "query": null}, "expected": null},
    {"name": "an array is not a query", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "LIST", "query": ["onDemand"]}, "expected": "read.source.query is not an object of fixed query parameters (AD-36)"},
    {"name": "a string is not a query", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "LIST", "query": "onDemand=1"}, "expected": "read.source.query is not an object of fixed query parameters (AD-36)"},
    {"name": "a query on the management port", "source": {"port": "mgmnt", "endpoint": "Applications", "type": "LIST", "query": {"onDemand": "1"}}, "expected": "read.source.query is declared on a 'mgmnt' source, and fixed query parameters travel on admin endpoints (AD-36)"},
    {"name": "a query on a state source", "source": {"port": "state", "endpoint": "Agent", "type": "LIST", "query": {"onDemand": "1"}}, "expected": "read.source.query is declared on a 'state' source, and fixed query parameters travel on admin endpoints (AD-36)"},
    {"name": "an empty query", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "LIST", "query": {}}, "expected": "read.source.query is empty, and a declared query fixes at least one parameter (AD-36)"},
    {"name": "a key that is not a parameter name", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "LIST", "query": {"on-demand": "1"}}, "expected": "read.source.query key 'on-demand' is not a query parameter name"},
    {"name": "a key a read's callers already send", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "LIST", "query": {"maxRows": "5"}}, "expected": "read.source.query key 'maxRows' collides with a name the read's own callers already send"},
    {"name": "a reserved key is compared case-folded", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "LIST", "query": {"onDemand": "1", "NS": "USER"}}, "expected": "read.source.query key 'NS' collides with a name the read's own callers already send"},
    {"name": "a key a criterion also declares, case-folded", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "UPCOMING", "query": {"hoursoffset": "24"}}, "criteria": {"fields": [{"param": "hoursOffset", "labelKey": "tableColumnName", "kind": "text", "maxLength": 3}]}, "expected": "read.source.query key 'hoursoffset' is also a read.criteria param, and no caller can change a fixed parameter (AD-36)"},
    {"name": "a key a criterion's vendorParam also declares, case-folded", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "HISTORY", "query": {"Who": "1"}}, "criteria": {"fields": [{"param": "search", "vendorParam": "who", "labelKey": "tableColumnName", "kind": "text", "maxLength": 100}]}, "expected": "read.source.query key 'Who' is also a read.criteria param, and no caller can change a fixed parameter (AD-36)"},
    {"name": "a number value", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "LIST", "query": {"onDemand": 1}}, "expected": "read.source.query 'onDemand' is not a non-empty string of at most 50 characters"},
    {"name": "an empty value", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "LIST", "query": {"onDemand": ""}}, "expected": "read.source.query 'onDemand' is not a non-empty string of at most 50 characters"},
    {"name": "a value of fifty-one characters", "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "LIST", "query": {"onDemand": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}}, "expected": "read.source.query 'onDemand' is not a non-empty string of at most 50 characters"},
    {"name": "three sound parts merged into <as>.<member> fields (Story 6.9)", "source": {"port": "admin", "endpoint": "Monitor", "type": "GET", "parts": [{"type": "SYSTEMUSAGE", "as": "Usage"}, {"type": "SYSTEMUSAGESHM", "as": "SharedMemory"}, {"type": "DASHBOARDMAIN", "as": "Dashboard"}]}, "fields": ["Usage.AllGlobalReferences", "SharedMemory.SMHUsed", "Dashboard.Performance.GlobalRefsPerSecond"], "filter": [], "sort": {"fields": ["Usage.AllGlobalReferences"], "default": "Usage.AllGlobalReferences", "direction": "asc"}, "table": {"columns": [{"field": "Usage.AllGlobalReferences", "labelKey": "tableColumnName", "kind": "name"}], "emptyNextKey": "tableReadOnlyEmptyNext", "emptyAgentKey": ""}, "context": {"fields": ["Usage.AllGlobalReferences", "SharedMemory.SMHUsed", "Dashboard.Performance.GlobalRefsPerSecond"], "secretFields": []}, "expected": null},
    {"name": "parts is not an array", "source": {"port": "admin", "endpoint": "Monitor", "type": "GET", "parts": "Usage"}, "expected": "read.source.parts is not an array of {type, as} parts (AD-36)"},
    {"name": "parts on a LIST source", "source": {"port": "admin", "endpoint": "Monitor", "type": "LIST", "parts": [{"type": "SYSTEMUSAGE", "as": "Usage"}]}, "expected": "read.source.parts is declared on a 'LIST' source, and parts merge into a single-object GET's one row (AD-36)"},
    {"name": "parts beside a parent-scoped route-id criterion", "source": {"port": "admin", "endpoint": "Monitor", "type": "GET", "parts": [{"type": "SYSTEMUSAGE", "as": "Usage"}]}, "criteria": {"fields": [{"param": "x", "labelKey": "tableColumnName", "kind": "text", "maxLength": 10}]}, "parentScope": "tasks/schedule", "expected": "read.source.parts is declared with read.criteria, and a parts read takes no criterion (AD-36)"},
    {"name": "parts beside a fixed query", "source": {"port": "admin", "endpoint": "Monitor", "type": "GET", "parts": [{"type": "SYSTEMUSAGE", "as": "Usage"}], "query": {"a": "1"}}, "expected": "read.source.parts is declared with read.source.query, and a parts read fixes no query parameter (AD-36)"},
    {"name": "four parts", "source": {"port": "admin", "endpoint": "Monitor", "type": "GET", "parts": [{"type": "SYSTEMUSAGE", "as": "Usage"}, {"type": "SYSTEMUSAGESHM", "as": "SharedMemory"}, {"type": "DASHBOARDMAIN", "as": "Dashboard"}, {"type": "FOO", "as": "Extra"}]}, "expected": "read.source.parts declares 4 part(s), and a parts read names 1 to 3"},
    {"name": "zero parts", "source": {"port": "admin", "endpoint": "Monitor", "type": "GET", "parts": []}, "expected": "read.source.parts declares 0 part(s), and a parts read names 1 to 3"},
    {"name": "a part that is not an object", "source": {"port": "admin", "endpoint": "Monitor", "type": "GET", "parts": ["Usage"]}, "expected": "read.source.parts entry #1 is not an object declaring its type and as"},
    {"name": "a part with an unknown key", "source": {"port": "admin", "endpoint": "Monitor", "type": "GET", "parts": [{"type": "SYSTEMUSAGE", "as": "Usage", "label": "x"}]}, "expected": "read.source.parts entry #1 declares the unknown key 'label'"},
    {"name": "a part type that is not upper-case", "source": {"port": "admin", "endpoint": "Monitor", "type": "GET", "parts": [{"type": "systemusage", "as": "Usage"}]}, "expected": "read.source.parts entry #1 type 'systemusage' is not upper-case letters"},
    {"name": "a part as that is not upper camel-case", "source": {"port": "admin", "endpoint": "Monitor", "type": "GET", "parts": [{"type": "SYSTEMUSAGE", "as": "usage"}]}, "expected": "read.source.parts entry #1 as 'usage' is not an upper camel-case identifier"},
    {"name": "a repeated part as", "source": {"port": "admin", "endpoint": "Monitor", "type": "GET", "parts": [{"type": "SYSTEMUSAGE", "as": "Usage"}, {"type": "SYSTEMUSAGESHM", "as": "Usage"}]}, "expected": "read.source.parts entry #2 names the as 'Usage' twice, and every part's as is unique"},
    {"name": "a field outside every declared part's as", "source": {"port": "admin", "endpoint": "Monitor", "type": "GET", "parts": [{"type": "SYSTEMUSAGE", "as": "Usage"}]}, "fields": ["Usage.AllGlobalReferences", "Other.Foo"], "expected": "read.fields 'Other.Foo' does not start with a declared parts.as followed by one or two segments (AD-36)"},
    {"name": "a sound parent-scoped VOLUMELIST source (Story 6.11)", "source": {"port": "admin", "endpoint": "Database.SysCRUD", "type": "VOLUMELIST"}, "criteria": {"fields": [{"param": "dir", "labelKey": "tableColumnName", "kind": "text", "maxLength": 256}]}, "parentScope": "os-management/databases", "expected": null},
    {"name": "a VOLUMELIST source on the management port", "source": {"port": "mgmnt", "endpoint": "Applications", "type": "VOLUMELIST"}, "expected": "read.source.type 'VOLUMELIST' is declared on a 'mgmnt' source, and a list-shaped request type other than LIST issues an admin endpoint (AD-36)"},
    {"name": "a VOLUMELIST source on a state source", "source": {"port": "state", "endpoint": "Agent", "type": "VOLUMELIST"}, "expected": "read.source.type 'VOLUMELIST' is declared on a 'state' source, and a list-shaped request type other than LIST issues an admin endpoint (AD-36)"},
    {"name": "a VOLUMELIST source with a detail call", "source": {"port": "admin", "endpoint": "Database.SysCRUD", "type": "VOLUMELIST", "rowGet": {"key": "File", "param": "dir", "type": "INFO", "fields": ["Size"], "derived": []}}, "expected": "read.source.rowGet is declared on a VOLUMELIST source, whose rows are volume files with no detail call to issue (AD-36)"},
    {"name": "a VOLUMELIST source with a parent list", "source": {"port": "admin", "endpoint": "Database.SysCRUD", "type": "VOLUMELIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": []}}, "expected": "read.source.forEach is declared on a VOLUMELIST source, which lists no parents (AD-36)"}
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

/// <p>The corpus declaration with <var>pCase</var>'s <code>source</code> in place, its
/// <code>criteria</code> when it carries one, and its <code>parentScope</code> when it carries one
/// (Story 6.7), as a new object.</p>
/// <p>A part-shaped case may also override <code>fields</code>, <code>filter</code>,
/// <code>sort</code>, <code>table</code> and <code>context</code> -- the corpus's shared OAuth
/// declaration carries fields no parts field can start with, so a case that exercises a parts
/// field or the sound shape supplies a self-consistent set of these five together, replacing the
/// default rather than colliding with it (Story 6.9).</p>
ClassMethod DeclarationFor(pCorpus As %DynamicObject, pCase As %DynamicObject) As %DynamicObject
{
    Set tDeclaration = ##class(%DynamicObject).%FromJSON(pCorpus.declaration.%ToJSON())
    Do tDeclaration.read.%Set("source", ##class(%DynamicObject).%FromJSON(pCase.source.%ToJSON()))
    If pCase.%GetTypeOf("criteria") = "object" Do tDeclaration.read.%Set("criteria", ##class(%DynamicObject).%FromJSON(pCase.criteria.%ToJSON()))
    If pCase.%GetTypeOf("parentScope") = "string" Do tDeclaration.%Set("parentScope", pCase.parentScope)
    If pCase.%GetTypeOf("fields") = "array" Do tDeclaration.read.%Set("fields", ##class(%DynamicAbstractObject).%FromJSON(pCase.fields.%ToJSON()))
    If pCase.%GetTypeOf("filter") = "array" Do tDeclaration.read.%Set("filter", ##class(%DynamicAbstractObject).%FromJSON(pCase.filter.%ToJSON()))
    If pCase.%GetTypeOf("sort") = "object" Do tDeclaration.read.%Set("sort", ##class(%DynamicObject).%FromJSON(pCase.sort.%ToJSON()))
    If pCase.%GetTypeOf("table") = "object" Do tDeclaration.%Set("table", ##class(%DynamicObject).%FromJSON(pCase.table.%ToJSON()))
    If pCase.%GetTypeOf("context") = "object" Do tDeclaration.%Set("context", ##class(%DynamicObject).%FromJSON(pCase.context.%ToJSON()))
    Quit tDeclaration
}

}
