/// <p>The superserver editor's Save (AD-55, Story 18.25): <code>POST /superserver</code> creates one
/// superserver through <class>OcuPilot.Screen.Tool.SuperserverCreate</class>, and <code>PUT
/// /superserver/:id</code> changes one through <class>OcuPilot.Screen.Tool.SuperserverUpdate</class>, the tools
/// the agent's mint and confirm read. It is <class>OcuPilot.Kernel.Proposal.ScreenSave</class> over the rules of
/// <class>OcuPilot.Area.Security.SuperserverRules</class>. The delete is a row action
/// (<class>OcuPilot.Screen.Tool.SuperserverDelete</class>) and has no route here.</p>
/// <p>A superserver is addressed by its composite id <code>[Port, BindAddress]</code>, the port numeric. The answer
/// is <code>{id, readBack, consequence}</code>, <code>id</code> in its canonical spelling, and the last when the change
/// carries one. An edit's merge is the tool's raw merge, the rules judge the payload it would send, and its
/// consequence is the effect the change has on the superserver the web gateway connects through
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.WeakensByEffect</method>). <b>No body carries
/// <code>SystemDefault</code></b>: the merge leaves it out, and a body that names it is 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>.</p>
Class OcuPilot.Area.Security.SuperserverSave Extends OcuPilot.Kernel.Proposal.ScreenSave
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.SuperserverCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.SuperserverUpdate";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.SuperserverForm";

Parameter RULES = "OcuPilot.Area.Security.SuperserverRules";

/// <p>The create body's two identifying members, which are not settings.</p>
Parameter PORTMEMBER = "Port";

Parameter BINDMEMBER = "BindAddress";

ClassMethod IdentityMembers() As %List
{
    Quit $ListBuild(..#PORTMEMBER, ..#BINDMEMBER)
}

/// <p>The identity is <code>$ListBuild(port, bind address)</code>, the port as text whether the body sends text or a
/// number, and the id is their composite. A bind address that is not text is a <code>PORT.FIELDSHAPE</code>
/// violation.</p>
ClassMethod CreateIdentity(pBody As %DynamicObject, Output pId As %String, Output pParts As %List, ByRef pShape)
{
    Set tPort = ""
    If (pBody.%GetTypeOf(..#PORTMEMBER) = "string") || (pBody.%GetTypeOf(..#PORTMEMBER) = "number") Set tPort = pBody.%Get(..#PORTMEMBER) _ ""
    Set tBind = ""
    Set tBindType = pBody.%GetTypeOf(..#BINDMEMBER)
    If tBindType = "string" Set tBind = pBody.%Get(..#BINDMEMBER)
    If (tBindType '= "string") && (tBindType '= "unassigned") Do ..Add(.pShape, ..#BINDMEMBER, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
    Set pParts = $ListBuild(tPort, tBind)
    Set pId = ##class(OcuPilot.Kernel.EntityId).JoinComposite(pParts)
}

ClassMethod RulesCheck(pMode As %String, pParts As %List, pBody As %DynamicObject, pFresh As %DynamicObject, pFull As %Boolean, Output pViolations) As %Status
{
    If pMode = "create" Quit $ClassMethod(..#RULES, "Check", $ListGet(pParts, 1), pBody, pFresh, pMode, ..PortClass(), .pViolations, pFull, $ListGet(pParts, 2))
    Quit $ClassMethod(..#RULES, "Check", "", pBody, pFresh, pMode, ..PortClass(), .pViolations, pFull)
}

ClassMethod RulesTaken(pParts As %List, pId As %String, Output pTaken As %Boolean) As %Status
{
    Quit $ClassMethod(..#RULES, "Taken", ..PortClass(), pId, .pTaken)
}

ClassMethod TakenField() As %String
{
    Quit "Port"
}

ClassMethod Subject() As %String
{
    Quit "superserver"
}

/// <p>The tool's raw merge, which leaves <code>SystemDefault</code> out of the payload. A problem it reports is not
/// judged by the rules: <method>CheckMerged</method> judges the payload instead.</p>
ClassMethod Merge(pToolClass As %String, pFresh As %DynamicObject, pArgs As %DynamicObject, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set pProblem = ""
    Quit $ClassMethod(pToolClass, "MergeRaw", pFresh, pArgs, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), .pPayload, .pDiff, .pUnchanged, .pProblem)
}

ClassMethod CheckMerged() As %Boolean
{
    Quit 1
}

/// <p>The effect the change has over the fresh read (<method>OcuPilot.Kernel.Proposal.Prohibited.WeakensByEffect</method>);
/// a superserver whose effect cannot be read is taken to be serving.</p>
ClassMethod Consequence(pId As %String, pPayload As %DynamicObject, pFresh As %DynamicObject, Output pConsequence As %String)
{
    Set pConsequence = ""
    Set tEffectSC = $ClassMethod(..ProhibitedClass(), "WeakensByEffect", ##class(OcuPilot.Kernel.Proposal.Prohibited).#TYPESUPERSERVER, pPayload, pFresh, .pConsequence, pId)
    If $$$ISERR(tEffectSC) Set pConsequence = ##class(OcuPilot.Kernel.Proposal.Prohibited).#EFFECTSERVINGSUPERSERVER
}

}
