/// <p>The global mappings list's edit tool (Story 18.14): propose a change to one global mapping's
/// fields (<class>OcuPilot.Screen.Tool.MappingUpdate</class>).</p>
Class OcuPilot.Screen.Tool.GlobalMappingUpdate Extends OcuPilot.Screen.Tool.MappingUpdate
{

Parameter TOOLNAME = "osmgmt.globalmappings.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.GlobalMappingList";

Parameter DESCRIPTION = "Propose a change to one global mapping of one namespace. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the namespace and the mapping as its global mappings list reports them and send only the fields to change. The mapping's name cannot be changed.";

Parameter ENDPOINT = "Namespace.GlobalMappings";

Parameter MAPPINGKIND = "global";

Parameter PERMITTEDFIELDS = "Database,LockDatabase,Collation";

/// <p>The classic dialog whose operation this tool performs beyond the list's own (AD-44,
/// DW-1784).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Mappings.Global";

}
