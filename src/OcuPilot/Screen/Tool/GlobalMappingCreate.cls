/// <p>The global mappings list's create tool (Story 18.14): propose a new global mapping in one
/// namespace (<class>OcuPilot.Screen.Tool.MappingCreate</class>).</p>
Class OcuPilot.Screen.Tool.GlobalMappingCreate Extends OcuPilot.Screen.Tool.MappingCreate
{

Parameter TOOLNAME = "osmgmt.globalmappings.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.GlobalMappingList";

Parameter DESCRIPTION = "Propose a new global mapping in one namespace, so the namespace reads the named globals from another database. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name the namespace, the global to map and the database.";

Parameter ENDPOINT = "Namespace.GlobalMappings";

Parameter MAPPINGKIND = "global";

Parameter PERMITTEDFIELDS = "Database,LockDatabase,Collation";

/// <p>The classic dialog whose operation this tool performs beyond the list's own (AD-44,
/// DW-1784).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Mappings.Global";

}
