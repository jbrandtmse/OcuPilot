/// <p>The routine mappings list's delete tool (Story 18.14): propose deleting one routine mapping
/// (<class>OcuPilot.Screen.Tool.MappingDelete</class>).</p>
Class OcuPilot.Screen.Tool.RoutineMappingDelete Extends OcuPilot.Screen.Tool.MappingDelete
{

Parameter TOOLNAME = "osmgmt.routinemappings.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RoutineMappingList";

Parameter DESCRIPTION = "Propose deleting one routine mapping of one namespace. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the namespace and the mapping as its routine mappings list reports them. The namespace then reads what the mapping named from its default database again; no data is deleted.";

Parameter ENDPOINT = "Namespace.RoutineMappings";

Parameter MAPPINGKIND = "routine";

/// <p>The top-level names the vendor's <code>GET</code> answers, read off its <code>ObjToJson</code>
/// on this build.</p>
Parameter READANSWERS = "Database";

Parameter FINGERPRINTSUBJECT = "Database";

}
