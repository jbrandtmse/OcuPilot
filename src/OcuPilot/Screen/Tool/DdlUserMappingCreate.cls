/// <p>User DDL mappings' New mapping (Story 21.13, AD-3, AD-6, AD-54, AD-55, AD-58): create one user DDL mapping on this instance
/// (<code>Config.SqlUserDatatypes</code>), which maps a DDL type name to a datatype class. Two callers reach it: the list's New mapping
/// dialog through <class>OcuPilot.Area.OsMgmt.DdlMappingSave</class>, and the agent's proposal and confirmation. The mapping is in effect
/// for the next DDL statement that names the type.</p>
/// <p><b>A create</b> (AD-54): its fresh read asks the port for the absence read of a create, so a name the instance holds is
/// <code>CONFIG.MAPPING.TAKEN</code> and a free one the 404 a create expects; a name taken since the mint closes the proposal
/// target-changed. Its payload is the datatype (<code>Value</code>); the name is the target's id. The name and the datatype are judged
/// by <class>OcuPilot.Area.OsMgmt.ConfigSettingRules</class> at the mint, at the Save and at the port, and its read-back compares the
/// datatype (<parameter>READBACKFIELDS</parameter>).</p>
Class OcuPilot.Screen.Tool.DdlUserMappingCreate Extends OcuPilot.Screen.Tool.ConfigSettingSet
{

Parameter TOOLNAME = "osmgmt.userddlmappings.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DdlUserMappingList";

Parameter DESCRIPTION = "Propose adding one user DDL mapping to this instance: a DDL type name and the datatype class it maps to. It changes nothing by itself: it answers a proposal the user reviews and confirms. Give the new type's name and its datatype, a class name with its parameters in parentheses if it takes any. A name this instance already holds, a name over 64 characters or holding =, comma, *, ^ or a control character, and a datatype that is not a class name are refused. The mapping applies to DDL statements that name the type afterwards.";

Parameter ENDPOINTNAME = "UserDDL";

Parameter CLASSICPAGES = "%CSP.UI.Portal.Config.SQLDataTypes,%CSP.UI.Portal.Config.SQLDataType";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "CREATE";

/// <p>No screen action carries a create: the list's New mapping reaches this tool through the Save route.</p>
Parameter SCREENACTIONS = "";

Parameter SCREENVALUES = "";

Parameter SCREENEMPTY = "";

/// <p>The create's own read asks for the absence read, which it composes from the stored payload (<method>PortQuery</method>).</p>
Parameter READSVALUES As BOOLEAN = 1;

/// <p>The read-back re-reads the created mapping through the set tool's single-object read, because this tool's own read asks for the
/// create and answers a held name as <code>TAKEN</code> (AD-58).</p>
Parameter READBACKTOOL = "OcuPilot.Screen.Tool.DdlUserMappingSet";

Parameter PRECONDITIONCODES = "CONFIG.MAPPING.TAKEN";

ClassMethod NameDescription() As %String
{
    Quit "The new DDL type's name: 1 to 64 characters with no =, comma, *, ^ or control character and no space at either end. A name this instance already holds is refused, so check the User DDL mappings list first."
}

ClassMethod ValueDescription() As %String
{
    Quit "The datatype the new type maps to, as text: a datatype class name, with its parameters in parentheses if it takes any, of up to 256 characters. A value that is not one is refused."
}

/// <p>The name of the mapping the confirmed create <var>pWritten</var> made, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If pWritten.%GetTypeOf("Name") '= "string" Quit ""
    Quit pWritten.%Get("Name")
}

/// <p>The read asks for the absence read of a create (<parameter>OcuPilot.Port.ConfigPort.ACTIONKEY</parameter>), at the mint, the
/// confirm and a Save alike: present is <code>TAKEN</code> and absent is the 404 a create expects (AD-54).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Set pQuery(##class(OcuPilot.Port.ConfigPort).#ACTIONKEY) = ..#WRITETYPE
}

/// <p>A create states no consequence.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ""
}

}
