/// <p>The routine mappings list's create tool (Story 18.14): propose a new routine mapping in one
/// namespace (<class>OcuPilot.Screen.Tool.MappingCreate</class>).</p>
Class OcuPilot.Screen.Tool.RoutineMappingCreate Extends OcuPilot.Screen.Tool.MappingCreate
{

Parameter TOOLNAME = "osmgmt.routinemappings.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RoutineMappingList";

Parameter DESCRIPTION = "Propose a new routine mapping in one namespace, so the namespace reads the named routines from another database. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name the namespace, the routine to map and the database.";

Parameter ENDPOINT = "Namespace.RoutineMappings";

Parameter MAPPINGKIND = "routine";

Parameter PERMITTEDFIELDS = "Database";

/// <p>The classic dialog whose operation this tool performs beyond the list's own (AD-44,
/// DW-1784).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Mappings.Routine";

}
