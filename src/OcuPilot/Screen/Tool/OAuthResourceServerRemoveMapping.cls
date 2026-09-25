/// <p>The OAuth 2.0 screen's remove-mapping tool (AD-51, AD-56 (ii)): propose that one resource server
/// stop validating tokens for a Web Gateway application or an ODBC/JDBC namespace it holds. It is
/// <class>OcuPilot.Screen.Tool.OAuthResourceServerAddMapping</class> read the other way: the same
/// read, arguments, port query and fingerprint, the port's <code>REMOVEMAPPING</code> write, and a
/// precondition that this server holds the mapping. Removing a mapping moves nothing, so it names no
/// effect.</p>
Class OcuPilot.Screen.Tool.OAuthResourceServerRemoveMapping Extends OcuPilot.Screen.Tool.OAuthResourceServerAddMapping
{

Parameter TOOLNAME = "security.oauthresourceservers.removemapping";

Parameter DESCRIPTION = "Propose that one OAuth 2.0 resource server on this instance stops validating the access tokens of a Web Gateway application (Service %Service_WebGateway, Key its name) or an ODBC/JDBC namespace (Service %Service_Bindings, Key the namespace) it holds. It changes nothing by itself: it answers a proposal the user reviews and confirms. A mapping this server does not hold is refused.";

Parameter WRITETYPE = "REMOVEMAPPING";

/// <p>What the precondition reads: this server's own mappings.</p>
Parameter PRECONDITIONFIELD = "Mappings";

Parameter MAPPINGMODE = "remove";

/// <p>None: a removal moves nothing.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ""
}

}
