/// <p>The Web applications list's write tool (AD-6, AD-10): propose a change to one web
/// application's configuration. It reads the application fresh through the vendor's own
/// <code>WebApp.App</code> <code>GET</code>, merges the arguments over that object, and mints a
/// proposal the user confirms. It writes nothing.</p>
/// <p><b>It registers by being compiled.</b> <class>OcuPilot.Screen.Tool.Registry</class> lists
/// every concrete class under <package>OcuPilot</package> that extends the tool base, so adding
/// this class is the whole registration; the descriptor declares no action, and declaring one
/// would make the screen write-capable, which is Story 5.8's affordance and not this story's.</p>
/// <p><b>Two fields are excluded by name, and AD-10 has two halves for each</b>: they are absent
/// from the tool set, so the model cannot author them, and every change to them is refused at the
/// write by <class>OcuPilot.Kernel.Proposal.Prohibited</class> whatever the caller. They are
/// excluded because <i>every</i> change is prohibited -- <code>MatchRoles</code> grants privilege
/// through a path, and <code>DispatchClass</code> decides which compiled code answers at a URL.</p>
/// <p><b>Why <code>AutheEnabled</code> and <code>Resource</code> stay settable.</b> Only weakening
/// them is an effect AD-10 forbids -- adding the unauthenticated bit, and clearing a resource that
/// was set -- so hardening stays proposable and the asymmetry lives in the prohibited set, which
/// compares against the live target, rather than in a field list, which cannot.</p>
/// <p>The reviewed classification leaves the <code>MatchRoles</code> subtree unnamed as well, so
/// the generator emits it <code>secret</code> and the schema would refuse it on that ground too;
/// both exclusions are stated here because this is where a reader of the tool looks for them.</p>
Class OcuPilot.Screen.Tool.WebAppUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "webapp.list.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WebAppList";

Parameter DESCRIPTION = "Propose a change to one web application's configuration on this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the application exactly as the web applications list reports it, and send only the fields to change.";

/// <p>The subtree AD-10 forbids: a web application's application and matching roles.</p>
Parameter EXCLUDEDFIELD = "MatchRoles";

/// <p>The field that decides which compiled code answers at the application's address. Every
/// change to it is prohibited (DW-1207), so it is not advertised.</p>
Parameter EXCLUDEDDISPATCH = "DispatchClass";

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

/// <p><parameter>EXCLUDEDFIELD</parameter> and <parameter>EXCLUDEDDISPATCH</parameter>, so no path
/// of this tool admits a role grant or a repointed dispatch class.</p>
ClassMethod ExcludedFields() As %List
{
    Quit $ListBuild(..#EXCLUDEDFIELD, ..#EXCLUDEDDISPATCH)
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
