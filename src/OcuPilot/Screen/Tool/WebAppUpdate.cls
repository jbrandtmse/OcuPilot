/// <p>The Web applications list's write tool (AD-6, AD-10): propose a change to one web
/// application's configuration. It reads the application fresh through the vendor's own
/// <code>WebApp.App</code> <code>GET</code>, merges the arguments over that object, and mints a
/// proposal the user confirms. It writes nothing.</p>
/// <p><b>It registers by being compiled.</b> <class>OcuPilot.Screen.Tool.Registry</class> lists
/// every concrete class under <package>OcuPilot</package> that extends the tool base, so adding
/// this class is the whole registration; the descriptor declares no action, and declaring one
/// would make the screen write-capable, which is Story 5.8's affordance and not this story's.</p>
/// <p><b>The <code>MatchRoles</code> subtree is excluded by name</b> (AD-10): setting a web
/// application's roles grants privilege, which is not proposable at any confirmation level. The
/// reviewed classification leaves that subtree unnamed as well, so the generator emits it
/// <code>secret</code> and the schema would refuse it on that ground too; the exclusion is stated
/// here because this is where a reader of the tool looks for it.</p>
Class OcuPilot.Screen.Tool.WebAppUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "webapp.list.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WebAppList";

Parameter DESCRIPTION = "Propose a change to one web application's configuration on this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the application exactly as the web applications list reports it, and send only the fields to change.";

/// <p>The one subtree AD-10 forbids: a web application's application and matching roles.</p>
Parameter EXCLUDEDFIELD = "MatchRoles";

/// <p>The permission a change to a web application requires beyond the screen's own read set: the
/// vendor's endpoint gates on <code>%Admin_Secure</code>, and writing needs more than using it.</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "WRITE";

ClassMethod Endpoint() As %String
{
    Quit "WebApp.App"
}

/// <p>The field names the merge may set: every <code>ordinary</code> top-level literal of this
/// tool's own field-list entry, derived rather than transcribed (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>EXCLUDEDFIELD</parameter>, so no path of this tool admits a role grant.</p>
ClassMethod ExcludedFields() As %List
{
    Quit $ListBuild(..#EXCLUDEDFIELD)
}

/// <p>What the caller must hold: the screen's own pairs
/// (<method>OcuPilot.Screen.Gate.RequiredPairs</method>, which unions the declared set with the
/// classic page's custom resource) plus
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>. The pairs are
/// checked against the caller's current grants by the dispatcher before this tool runs, and again
/// at the write (AD-8, AD-40).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Quit tPairs _ $ListBuild($ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION))
}

}
