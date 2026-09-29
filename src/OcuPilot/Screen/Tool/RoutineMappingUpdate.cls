/// <p>The routine mappings list's edit tool (Story 18.14): propose a change to one routine mapping's
/// fields (<class>OcuPilot.Screen.Tool.MappingUpdate</class>).</p>
Class OcuPilot.Screen.Tool.RoutineMappingUpdate Extends OcuPilot.Screen.Tool.MappingUpdate
{

Parameter TOOLNAME = "osmgmt.routinemappings.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RoutineMappingList";

Parameter DESCRIPTION = "Propose a change to one routine mapping of one namespace. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the namespace and the mapping as its routine mappings list reports them and send only the fields to change. The mapping's name cannot be changed.";

Parameter ENDPOINT = "Namespace.RoutineMappings";

Parameter MAPPINGKIND = "routine";

Parameter PERMITTEDFIELDS = "Database";

/// <p>The classic dialog whose operation this tool performs beyond the list's own (AD-44,
/// DW-1784).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Mappings.Routine";

}
