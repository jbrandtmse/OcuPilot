/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Prohibited</class> subclass with one replaced seam:
/// <method>Target</method> answers a present mapping, <code>{Database: "USER", LockDatabase: "",
/// Collation: 5}</code>, for a change or a delete of a <code>%ALL</code> mapping the instance does not
/// hold, so the set's change and delete predicates are asked about <code>%ALL</code> without a
/// mapping written there (Story 18.14). A create, and every other target, is the shipped read.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.MappingAllTargetFixture Extends OcuPilot.Kernel.Proposal.Prohibited
{

ClassMethod Target(pToolName As %String, pId As %String, Output pTarget As %DynamicObject, Output pPresent As %Boolean, Output pToolClass As %String) As %Status [ Private ]
{
    Set tSC = ##super(pToolName, pId, .pTarget, .pPresent, .pToolClass)
    If $$$ISERR(tSC) || pPresent Quit tSC
    If $ZConvert($ListGet(##class(OcuPilot.Kernel.EntityId).SplitComposite(pId), 1), "U") '= "%ALL" Quit tSC
    If $ClassMethod(pToolClass, "Creates") Quit tSC
    Set pTarget = {"Database": "USER", "LockDatabase": "", "Collation": 5}
    Set pPresent = 1
    Quit tSC
}

}
