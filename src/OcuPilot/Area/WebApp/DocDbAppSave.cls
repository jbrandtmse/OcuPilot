/// <p>The Doc DB application editor's Save (AD-55, Story 18.30): <code>POST /docdb-application</code> creates one record
/// through <class>OcuPilot.Screen.Tool.DocDbAppCreate</class>, and <code>PUT /docdb-application/:id</code> changes one
/// through <class>OcuPilot.Screen.Tool.DocDbAppUpdate</class>, the tools the agent's mint and confirm read. It is
/// <class>OcuPilot.Kernel.Proposal.ScreenSave</class> over the rules of
/// <class>OcuPilot.Area.WebApp.DocDbAppRules</class>; the delete is a row action
/// (<class>OcuPilot.Screen.Tool.DocDbAppDelete</class>) and has no route here.</p>
/// <p>A record is addressed by its composite id <code>[Namespace, Name]</code>
/// (<class>OcuPilot.Kernel.EntityId</class>), which the tools' port splits: the namespace is sent upper-cased and the
/// name as typed. The answer is <code>{id, namespace, name, readBack}</code>. An edit's body names no identifying
/// member: a <code>Name</code> or <code>Namespace</code> in it is 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>, because an update never changes the id.</p>
Class OcuPilot.Area.WebApp.DocDbAppSave Extends OcuPilot.Kernel.Proposal.ScreenSave
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.DocDbAppCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.DocDbAppUpdate";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DocDbAppForm";

Parameter RULES = "OcuPilot.Area.WebApp.DocDbAppRules";

/// <p>The create body's identifying members, which are not settings.</p>
Parameter NAMEMEMBER = "Name";

Parameter NAMESPACEMEMBER = "Namespace";

/// <p>Whether a record is keyed by a namespace as well as a name: <parameter>RULES</parameter>' own declaration
/// (<parameter>OcuPilot.Area.WebApp.DocDbAppRules.NAMESPACED</parameter>). When it is 0 the body names no
/// <code>Namespace</code>, the id is the name, and the answer carries no namespace.</p>
ClassMethod Namespaced() As %Boolean
{
    Quit ''$Parameter(..#RULES, "NAMESPACED")
}

/// <p>The id of the record <var>pName</var> in <var>pNamespace</var>
/// (<method>OcuPilot.Area.WebApp.DocDbAppRules.IdOf</method>).</p>
ClassMethod IdOf(pNamespace As %String, pName As %String) As %String
{
    Quit $ClassMethod(..#RULES, "IdOf", pNamespace, pName)
}

ClassMethod IdentityMembers() As %List
{
    Quit $Select(..Namespaced(): $ListBuild(..#NAMESPACEMEMBER, ..#NAMEMEMBER), 1: $ListBuild(..#NAMEMEMBER))
}

/// <p>The identity is <code>$ListBuild(namespace, name)</code>, the namespace as typed and empty when the records are
/// not keyed by one. A member that is not text is a <parameter>OcuPilot.Api.Error.PORTFIELDSHAPE</parameter>
/// violation.</p>
ClassMethod CreateIdentity(pBody As %DynamicObject, Output pId As %String, Output pParts As %List, ByRef pShape)
{
    Set tNamespace = ""
    Set tName = ""
    Set tMembers = ..IdentityMembers()
    For tI = 1:1:$ListLength(tMembers) {
        Set tMember = $List(tMembers, tI)
        Set tType = pBody.%GetTypeOf(tMember)
        If tType = "string" {
            If tMember = ..#NAMESPACEMEMBER Set tNamespace = pBody.%Get(tMember)
            If tMember = ..#NAMEMEMBER Set tName = pBody.%Get(tMember)
        } ElseIf tType '= "unassigned" {
            Do ..Add(.pShape, tMember, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
    }
    Set pParts = $ListBuild(tNamespace, tName)
    Set pId = ..IdOf(tNamespace, tName)
}

/// <p>A composite id that is not two non-empty parts, or an empty name where the records are not keyed by a namespace,
/// names no whole record.</p>
ClassMethod UpdateIdentity(pDecoded As %String, Output pId As %String, Output pParts As %List) As %Boolean
{
    If ..Namespaced() {
        Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pDecoded)
        Set tNamespace = $ListGet(tParts, 1)
        Set tName = $ListGet(tParts, 2)
        Set tWhole = ($ListLength(tParts) = 2) && (tNamespace '= "") && (tName '= "")
    } Else {
        Set tNamespace = ""
        Set tName = pDecoded
        Set tWhole = (tName '= "")
    }
    Set pParts = $ListBuild(tNamespace, tName)
    Set pId = ..IdOf(tNamespace, tName)
    Quit tWhole
}

/// <p>The body as it is: an identifying member in an edit is an unexpected key.</p>
ClassMethod UpdateArguments(pBody As %DynamicObject) As %DynamicObject
{
    Quit pBody
}

ClassMethod RulesCheck(pMode As %String, pParts As %List, pBody As %DynamicObject, pFresh As %DynamicObject, pFull As %Boolean, Output pViolations) As %Status
{
    If pMode = "create" Quit $ClassMethod(..#RULES, "Check", $ListGet(pParts, 1), $ListGet(pParts, 2), pBody, pFresh, pMode, ..PortClass(), .pViolations, pFull)
    Quit $ClassMethod(..#RULES, "Check", "", "", pBody, pFresh, pMode, ..PortClass(), .pViolations, pFull)
}

ClassMethod RulesTaken(pParts As %List, pId As %String, Output pTaken As %Boolean) As %Status
{
    Quit $ClassMethod(..#RULES, "Taken", ..PortClass(), $ListGet(pParts, 1), $ListGet(pParts, 2), .pTaken)
}

/// <p>The answer is <code>{id, namespace, name}</code>, the namespace upper-cased as the instance stores it and
/// absent where the records are not keyed by one.</p>
ClassMethod AnswerBody(pId As %String, pParts As %List) As %DynamicObject
{
    Set tNamespace = $Select(..Namespaced(): $ZConvert($ListGet(pParts, 1), "U"), 1: "")
    Set tName = $ListGet(pParts, 2)
    Set tAnswer = {}
    Do tAnswer.%Set("id", ..IdOf(tNamespace, tName), "string")
    If ..Namespaced() Do tAnswer.%Set("namespace", tNamespace, "string")
    Do tAnswer.%Set("name", tName, "string")
    Quit tAnswer
}

}
