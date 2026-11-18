/// <p>The Globals list's export (Story 21.17, <class>OcuPilot.Screen.Tool.ExplorerExport</class>): one global of the route's
/// namespace, as the XML document <code>&lt;name&gt;.GBL</code>, to a server file or to this browser. The set is that one name.</p>
Class OcuPilot.Screen.Tool.ExplorerGlobalExport Extends OcuPilot.Screen.Tool.ExplorerExport
{

Parameter TOOLNAME = "explorer.globals.export";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerGlobalList";

Parameter DESCRIPTION = "Propose exporting one global of the route's namespace to one XML file on the server. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the global exactly as the Globals list reports it, without the ^, and name the file by `root`, an allowed directory exactly as the Allowed directories screen lists it, and `path`, a relative file name under it whose directory exists; an existing file at that name is replaced, so say so in the rationale. A global that holds no data, holds OcuPilot's own data, or holds more than 3,000,000 characters is refused. The exported XML goes to that file and is never shown to you.";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AtelierPort).#ENDPOINTGLOBALS
}

/// <p>The superclass's schema with <code>Names</code> described as the one global exported.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The one global to export, named as this namespace's Globals list reports it in its Name column, without the ^.", "string")
    }
    Quit tSchema
}

/// <p>What is wrong with <var>pValue</var> as the one global an export names, or <code>""</code>.</p>
ClassMethod SetProblem(pValue As %String) As %String
{
    If '$IsObject(pValue) && ($ListLength(##class(OcuPilot.Port.AtelierPort).SetNames(..Endpoint(), pValue)) > 0) Quit ""
    Quit "'" _ ..#IDARGUMENT _ "' names one global, as this namespace's Globals list reports it, without the ^"
}

}
