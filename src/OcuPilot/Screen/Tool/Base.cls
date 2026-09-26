/// <p>The base every agent tool extends (AD-22), and the one contract both registry sources answer
/// (DW-295). A tool declares, at definition time, its name (<parameter>TOOLNAME</parameter>,
/// <code>&lt;area&gt;.&lt;screen&gt;.&lt;verb&gt;</code> in lower case), its kind
/// (<parameter>KIND</parameter>, <code>read</code> or <code>write</code>) and a description, and it
/// answers its input schema, its result schema, its privilege pairs -- declared, and any an argument
/// adds -- and its view. A concrete tool
/// whose nearest <parameter>KIND</parameter> is neither fails the build in
/// <file>scripts/check-objectscript.py</file> and is refused by
/// <method>OcuPilot.Screen.Tool.Registry.KindProblem</method> on the instance.</p>
/// <p>Every method takes the descriptor a descriptor-derived tool is derived from as its first
/// argument; a tool with a class of its own receives <code>""</code> and ignores it.</p>
/// <p><b>A tool is called only through <method>OcuPilot.Screen.Tool.Registry.InvokeTool</method></b>,
/// whose one caller is <class>OcuPilot.Kernel.Agent.Dispatch</class>. The dispatcher has already
/// checked the governance gate, the restraint verdict for a write tool, the declared pairs against
/// the caller's current grants, the arguments, and the pairs the arguments add before
/// <method>View</method> runs.</p>
/// <p><b>A tool never touches <code>%session</code>, <code>%request</code> or
/// <code>$NAMESPACE</code>, and issues no HTTP request.</b> It runs in the caller's process with the
/// caller's identity (AD-1), and anything it needs about the caller or the scope is handed to it as
/// a value.</p>
Class OcuPilot.Screen.Tool.Base Extends %RegisteredObject [ Abstract ]
{

/// <p>The tool's name, <code>&lt;area&gt;.&lt;screen&gt;.&lt;verb&gt;</code>, lower case, dots
/// only (Conventions, Tool naming).</p>
Parameter TOOLNAME = "";

/// <p><code>read</code> or <code>write</code>. Empty here, so a concrete tool that declares
/// neither is refused.</p>
Parameter KIND = "";

/// <p><code>instance</code> or <code>client</code> (Story 4.7, AD-11 rule 3). An
/// <code>instance</code>-fulfilled tool -- every tool before this one -- is validated, gated and
/// answered by <method>View</method> in the calling process, as the rest of this class's header
/// describes. A <code>client</code>-fulfilled tool is validated, announced and gated the same way,
/// but its body runs in the browser: <class>OcuPilot.Kernel.Agent.Dispatch</class> never calls
/// <method>View</method> for it, records a directive instead, and the browser answers once on a
/// dedicated route. <code>OcuPilot.Screen.Tool.Registry</code> refuses <code>client</code> on a
/// <code>write</code>-kind tool at validation, so a write can never be decided in the browser.
/// Defaults to <code>instance</code>, so every existing tool needs no change.</p>
Parameter FULFILMENT = "instance";

/// <p>A one-line description of what the tool answers.</p>
Parameter DESCRIPTION = "";

/// <p>Whether the agent may reach this tool (AD-53's unadvertised case). <code>1</code> here. A
/// tool declaring <code>0</code> stays in <method>OcuPilot.Screen.Tool.Registry.ListTools</method>,
/// so its screen's own action route resolves it, while the provider tool list, the dispatch lookup
/// and the screen context's <code>tools</code> leave it out.</p>
Parameter ADVERTISED As BOOLEAN = 1;

/// <p>The tool's input schema, in the subset
/// <method>OcuPilot.Screen.Tool.Registry.ValidateArguments</method> admits.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject [ Abstract ]
{
    Quit {}
}

/// <p>The schema of the result <method>View</method> answers on success, in the same subset.
/// <code>""</code> here, so a tool that declares none is refused when the tools are advertised.</p>
ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ""
}

/// <p>The description the model is given for this tool: <parameter>DESCRIPTION</parameter>
/// unless a tool derives one from its descriptor.</p>
ClassMethod Description(pDescriptor As %String = "") As %String
{
    Quit ..#DESCRIPTION
}

/// <p><parameter>ADVERTISED</parameter> as a boolean. The registry reads the parameter itself when
/// it lists the tool, so the parameter, not an override of this method, is the declaration.</p>
ClassMethod Advertised() As %Boolean
{
    Quit ''..#ADVERTISED
}

/// <p>The <code>(resource, permission)</code> pairs a caller must hold for this tool, as a
/// <class>%List</class> of <code>$ListBuild(resource, permission)</code> (AD-8).
/// <var>pResolved</var> is 1 only when the requirement was read; a tool whose pairs cannot be read
/// answers 0 and is refused. None, resolved, here.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set pResolved = 1
    Quit ""
}

/// <p>The top-level argument property names whose values are secret, as a <class>%List</class>
/// (AD-3). <var>pDeclared</var> is 1 only when the tool has answered the question; the base answers
/// 0, so a concrete tool that declares nothing is refused when the tools are advertised
/// (<method>OcuPilot.Screen.Tool.Registry.ProviderTools</method>).</p>
/// <p><b>Refusing an undeclared tool is what keeps redaction schema-driven.</b> If silence meant
/// "no secrets", the schema layer would be advisory and the name pattern would be the real defense
/// -- the inversion AD-3 forbids, and the one
/// <method>OcuPilot.Kernel.Audit.Log.Redact</method>'s own header names ("a name pattern cannot see
/// a wallet secret stored in a field called <code>Value</code>"). Declaring none is an act:
/// answer <code>""</code> with <var>pDeclared</var> 1.</p>
/// <p>A method rather than a schema key because
/// <parameter>OcuPilot.Screen.Tool.Registry.SCHEMAKEYWORDS</parameter> admits no classification
/// keyword, and because a descriptor-driven tool must be able to vary its answer per
/// descriptor.</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 0
    Quit ""
}

/// <p>The pairs a call with arguments <var>pArgs</var> requires beyond
/// <method>PrivilegePairs</method>, where the requirement depends on an argument -- a namespace a
/// read names, for instance (AD-8, AD-48) -- in the same shape. <var>pArgs</var> is an object the
/// input schema admits. <var>pResolved</var> is 1 only when the requirement was read; a call whose
/// pairs cannot be read is refused. None, resolved, here.</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Set pResolved = 1
    Quit ""
}

/// <p>Answer the tool. <var>pArgs</var> is the model's input, <var>pContextCap</var> the most rows
/// the result may carry (AD-24), a whole number above zero supplied by the caller.</p>
/// <p>On success <var>pResult</var> is an object conforming to <method>ResultSchema</method>,
/// <var>pHttpStatus</var> 200 and <var>pFault</var> <code>""</code>. On failure the status is an
/// error, <var>pResult</var> is <code>""</code>, <var>pHttpStatus</var> the status a route would
/// answer and <var>pFault</var> the wire fault <code>{error, reason, code}</code>, plus
/// <code>detail</code> where there is one.</p>
ClassMethod View(pDescriptor As %String, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Abstract ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Quit $$$OK
}

/// <p>The refusal a view answers for arguments its input schema does not admit: 400,
/// <code>TOOL.ARGUMENTS</code>, and <var>pProblem</var> as <code>detail.problem</code>.</p>
ClassMethod ArgumentsRefusal(pProblem As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 400
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS)
    Set tDetail = {}
    Do tDetail.%Set("problem", pProblem, "string")
    Do pFault.%Set("detail", tDetail)
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS _ ": " _ pProblem)
}

/// <p>An internal failure of a view: 500 with the generic fault on the wire, and
/// <var>pDetail</var> in the status alone.</p>
ClassMethod InternalRefusal(pDetail As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Quit $$$ERROR($$$GeneralError, pDetail)
}

/// <p>The most rows a view asks its source for: <var>pCap</var>, or the model's
/// <code>maxRows</code> in <var>pArgs</var> when that is a smaller whole number.</p>
ClassMethod BoundedMaxRows(pArgs As %DynamicAbstractObject, pCap As %Integer) As %Integer
{
    Set tMax = +pCap
    If '$IsObject(pArgs) Quit tMax
    If pArgs.%GetTypeOf("maxRows") '= "number" Quit tMax
    Set tWanted = pArgs.%Get("maxRows")
    If $Match(tWanted, "^[1-9][0-9]*$") && (tWanted < tMax) Set tMax = +tWanted
    Quit tMax
}

}
