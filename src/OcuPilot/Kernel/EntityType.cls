/// <p>The closed entity-type vocabulary (AD-14). A screen descriptor selects its primary and
/// secondary entity types from this list and nothing else; a value that is not here fails the
/// build, in <file>scripts/check-objectscript.py</file> and again in
/// <file>ui/tools/screen-mirror.mjs</file>, rather than reaching two slices under two
/// spellings.</p>
/// <p>The kernel owns it, so a slice never invents a key. A later story that needs a value
/// adds it <b>here</b> and nowhere else; nothing derives a key from a class name, a route or a
/// display name.</p>
/// <p>The seed is the vocabulary the Release 1 screen lists imply
/// (<file>EXPERIENCE.md</file>'s side-bar screen lists, <file>epics.md</file>'s create and
/// import epic), one value per administered thing. The OAuth 2.0 family is five values: a
/// client configuration, a server definition, a resource server, an authorization server and a
/// server client. The admin API's sixth OAuth 2.0 endpoint,
/// <code>ResourceServerMapping</code>, relates two of those rather than administering a thing
/// of its own, so it has no key here; a story that needs one adds it.</p>
/// <p><code>agent-definition</code> and <code>agent-switch</code> are OcuPilot's own configuration
/// rather than the instance's, and they are values here for the same reason every other one is: the
/// Definitions list and the Switches screen publish AD-14's change event on them, and a key a slice
/// invented would be a second spelling. <code>agent-switch</code> covers the instance-wide switches
/// and the per-user holds together -- one screen administers both, and a hold is not a thing of its
/// own outside it.</p>
Class OcuPilot.Kernel.EntityType Extends %RegisteredObject
{

/// <p>The vocabulary, comma-separated and in no significant order. Lower-case with hyphens,
/// the same spelling shape route and area keys use, so a key is never confused with a class
/// name.</p>
Parameter TYPES = "web-application,rest-service,user,role,resource,service,ssl-configuration,x509-credential,ldap-configuration,wallet-collection,wallet-secret,oauth2-client-configuration,oauth2-server-definition,oauth2-resource-server,oauth2-server,oauth2-server-client,audit-event,task,task-history-entry,process,lock,database,device,audit-record,application-error,log-entry,agent-definition,agent-switch";

/// <p>Whether <var>pType</var> is one of the declared values. An empty string is <b>not</b>
/// known: a screen with no entity type declares the empty string and its descriptor is
/// exempted from this check by the registry, which is the one place that distinction is
/// made.</p>
ClassMethod IsKnown(pType As %String) As %Boolean
{
    If pType = "" Quit 0
    Quit $ListFind(..List(), pType) > 0
}

/// <p>The vocabulary as a <class>%List</class>, in declaration order.</p>
ClassMethod List() As %List
{
    Set tList = ""
    Set tRaw = ..#TYPES
    For tI = 1:1:$Length(tRaw, ",") {
        Set tValue = $Piece(tRaw, ",", tI)
        If tValue '= "" Set tList = tList _ $ListBuild(tValue)
    }
    Quit tList
}

/// <p>How many values the vocabulary holds. Exists so a test can pin the size without
/// re-spelling the list, which would be a second copy of it.</p>
ClassMethod Count() As %Integer
{
    Quit $ListLength(..List())
}

}
