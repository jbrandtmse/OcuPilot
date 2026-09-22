/// <p>The Web applications list's write tool (AD-6, AD-10): propose a change to one web
/// application's configuration. It reads the application fresh through the vendor's own
/// <code>WebApp.App</code> <code>GET</code>, merges the arguments over that object, and mints a
/// proposal the user confirms. It writes nothing.</p>
/// <p><b>It registers by being compiled.</b> <class>OcuPilot.Screen.Tool.Registry</class> lists
/// every concrete class under <package>OcuPilot</package> that extends the tool base, so adding
/// this class is the whole registration; the descriptor declares no action, and declaring one
/// would make the screen write-capable, which is Story 5.8's affordance and not this story's.</p>
/// <p><b>It admits four of the forty-five ordinary top-level fields its classified field list
/// carries</b> (<parameter>PERMITTEDFIELDS</parameter>), and AD-10 has two halves for every other
/// one: it is absent from the tool set, so the model cannot author it, and a change to it is
/// refused at the write by <class>OcuPilot.Kernel.Proposal.Prohibited</class> whatever the caller.
/// The four are the ones this release has reviewed; the rest decide which compiled code answers at
/// the URL (<code>DispatchClass</code>, <code>EventClass</code>, <code>SuperClass</code>,
/// <code>Package</code>, <code>Path</code>, <code>NameSpace</code>, the page properties, the WSGI
/// properties), how a caller gets in (<code>MatchRoles</code>, <code>TwoFactorEnabled</code>,
/// <code>CSRFToken</code>, <code>JWTAuthEnabled</code>, the session and CORS properties), or
/// something nobody has yet reviewed -- and a positive list is what keeps the next vendor property
/// out of the schema instead of admitting it until somebody notices.</p>
/// <p><b>Why <code>AutheEnabled</code> and <code>Resource</code> are among the four.</b> Each has
/// exactly one change AD-10 does not forbid -- clearing the option of reaching the application
/// without signing in, and setting a resource where none was set -- so that one change stays
/// proposable and the asymmetry lives in the prohibited set, which compares against the live
/// target, rather than in a field list, which cannot.</p>
/// <p><b>Two names are excluded as well as unpermitted</b>, because <i>every</i> change to them is
/// prohibited by a predicate of its own: <code>MatchRoles</code> grants privilege through a path,
/// and <code>DispatchClass</code> decides which compiled code answers at a URL (DW-1207). The
/// reviewed classification leaves the <code>MatchRoles</code> subtree unnamed too, so the generator
/// emits it <code>secret</code> and the schema would refuse it on that ground as well; the
/// exclusions are stated here because this is where a reader of the tool looks for them.</p>
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

/// <p>The only top-level fields this tool admits, comma-separated: the web-application settings
/// whose change AD-10's prohibited set has reviewed
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method>). A test asserts the
/// two agree; the kernel is never read from here.</p>
Parameter PERMITTEDFIELDS = "AutheEnabled,Description,Enabled,Resource";

/// <p>The pair a change to a web application requires: <code>%Admin_Secure:USE</code>, which is
/// exactly what <method>%CSP.Portal.Application.CheckSecurity</method> checks before the classic
/// editor saves, and exactly the pair
/// <class>OcuPilot.Screen.Descriptor.WebAppList</class> already declares for its own read. So the
/// resolved set is the screen's two pairs and nothing else, which is what makes "the same 403 the
/// editor would give" true by construction; no permission a shipped role does not grant appears on
/// the path (DW-1208).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

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

/// <p><parameter>PERMITTEDFIELDS</parameter>, so a field the prohibited set has not reviewed is
/// absent from the schema and from <method>SettableFields</method> whether or not anyone has
/// thought to exclude it by name.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>What the caller must hold: the screen's own pairs
/// (<method>OcuPilot.Screen.Gate.RequiredPairs</method>, which unions the declared set with the
/// classic page's custom resource) together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>. The pairs are
/// checked against the caller's current grants by the dispatcher before this tool runs, and again
/// at the write (AD-8, AD-40).</p>
/// <p><b>Each pair once.</b> The write's own pair is one the screen already declares, so appending
/// it unconditionally would put <code>%Admin_Secure:USE</code> in the resolved set twice and the
/// ledger row's pair column would record one check as two (DW-1208).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
