/// <p>The base every agent tool extends (AD-22). A tool declares, at definition time, its name
/// (<parameter>TOOLNAME</parameter>, <code>&lt;area&gt;.&lt;screen&gt;.&lt;verb&gt;</code> in lower
/// case), its kind (<parameter>KIND</parameter>, <code>read</code> or <code>write</code>) and a
/// description, and it answers its input schema. A concrete tool whose nearest
/// <parameter>KIND</parameter> is neither fails the build in
/// <file>scripts/check-objectscript.py</file> and is refused by
/// <method>OcuPilot.Screen.Tool.Registry.KindProblem</method> on the instance.</p>
/// <p><b>Nothing here dispatches.</b> The dispatch path, its caller context, its call-time gate
/// point and its audit row are Story 4.2's; this base carries no invocation method.</p>
/// <p><b>A tool never touches <code>%session</code>, <code>%request</code> or
/// <code>$NAMESPACE</code>.</b> It runs in the caller's process with the caller's identity (AD-1),
/// and anything it needs about the caller or the scope is handed to it as a value.</p>
Class OcuPilot.Screen.Tool.Base Extends %RegisteredObject [ Abstract ]
{

/// <p>The tool's name, <code>&lt;area&gt;.&lt;screen&gt;.&lt;verb&gt;</code>, lower case, dots
/// only (Conventions, Tool naming).</p>
Parameter TOOLNAME = "";

/// <p><code>read</code> or <code>write</code>. Empty here, so a concrete tool that declares
/// neither is refused.</p>
Parameter KIND = "";

/// <p>A one-line description of what the tool answers.</p>
Parameter DESCRIPTION = "";

/// <p>The tool's input schema, in the subset
/// <method>OcuPilot.Screen.Tool.Registry.ValidateArguments</method> admits.
/// <var>pDescriptor</var> names the screen descriptor a descriptor-derived tool is derived from; a
/// tool with a class of its own ignores it.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject [ Abstract ]
{
    Quit {}
}

}
