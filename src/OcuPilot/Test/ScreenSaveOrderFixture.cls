/// <p>Test-only <class>OcuPilot.Area.Security.MftConnectionSave</class> subclass for the shared Save's template tests
/// (<class>OcuPilot.Test.ScreenSaveOrder</class>): its two tools and its port are
/// <class>OcuPilot.Test.ScreenSaveMftCreate</class>, <class>OcuPilot.Test.ScreenSaveMftUpdate</class> and
/// <class>OcuPilot.Test.ScreenSaveMemoryPort</class>, which keep every connection in process memory, its prohibited set
/// is <class>OcuPilot.Test.ScreenSaveSet</class>, and its rules class is
/// <class>OcuPilot.Test.ScreenSaveOrderRules</class>. Each step of the template and each hook records itself in
/// <class>OcuPilot.Test.ScreenSaveTrace</class> and then does what the shipped Save does. <method>Handle</method>,
/// inherited from <class>OcuPilot.Test.MftSaveFixture</class>, runs one route in this process against request and
/// response stubs.</p>
/// <p>Armed <code>gate</code>, <method>Gate</method> refuses the caller; armed <code>checkmerged</code>,
/// <method>CheckMerged</method> answers 1; armed <code>throwanswer</code>, <method>Answer</method> raises an
/// exception. A create whose identity has a shape violation is given the id <parameter>SHAPEID</parameter>, and the
/// edit id <parameter>NOTWHOLE</parameter> names no whole target, so the hold has a lock to take where the shipped
/// identity would give it none.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ScreenSaveOrderFixture Extends OcuPilot.Test.MftSaveFixture
{

Parameter CREATETOOL = "OcuPilot.Test.ScreenSaveMftCreate";

Parameter UPDATETOOL = "OcuPilot.Test.ScreenSaveMftUpdate";

Parameter RULES = "OcuPilot.Test.ScreenSaveOrderRules";

/// <p>The id this fixture gives a create whose identity has a shape violation.</p>
Parameter SHAPEID = "shape-probe";

/// <p>The edit id that names no whole target and, in this fixture, still names one to hold.</p>
Parameter NOTWHOLE = "no-whole-target";

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.ScreenSaveMemoryPort"
}

ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Test.ScreenSaveSet"
}

ClassMethod Gate(Output pRefused As %Boolean, pWriteTool As %String = "") As %Status
{
    Do ##class(OcuPilot.Test.ScreenSaveTrace).Mark("gate")
    If ##class(OcuPilot.Test.ScreenSaveTrace).Armed("gate") {
        Set pRefused = 1
        Quit ##class(OcuPilot.Kernel.Denial).Envelope("%Admin_Secure:USE")
    }
    Quit ##super(.pRefused, pWriteTool)
}

ClassMethod Body(Output pBody As %DynamicObject) As %Boolean [ Private ]
{
    Do ##class(OcuPilot.Test.ScreenSaveTrace).Mark("body")
    Quit ##super(.pBody)
}

ClassMethod CreateIdentity(pBody As %DynamicObject, Output pId As %String, Output pParts As %List, ByRef pShape)
{
    Do ##class(OcuPilot.Test.ScreenSaveTrace).Mark("identity")
    Do ##super(pBody, .pId, .pParts, .pShape)
    If $Get(pShape) > 0 Set pId = ..#SHAPEID
}

ClassMethod UpdateIdentity(pDecoded As %String, Output pId As %String, Output pParts As %List) As %Boolean
{
    Do ##class(OcuPilot.Test.ScreenSaveTrace).Mark("identity")
    Set tWhole = ##super(pDecoded, .pId, .pParts)
    If pDecoded = ..#NOTWHOLE Quit 0
    Quit tWhole
}

ClassMethod Unexpected(pToolClass As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Do ##class(OcuPilot.Test.ScreenSaveTrace).Mark("unexpected")
    Quit ##super(pToolClass, pArgs, .pHttpStatus, .pFault)
}

ClassMethod RulesCheck(pMode As %String, pParts As %List, pBody As %DynamicObject, pFresh As %DynamicObject, pFull As %Boolean, Output pViolations) As %Status
{
    Do ##class(OcuPilot.Test.ScreenSaveTrace).Mark("rules:" _ pMode _ ":" _ $Select(pFull: "full", 1: "shape"))
    Quit ##super(pMode, pParts, pBody, pFresh, pFull, .pViolations)
}

ClassMethod RulesTaken(pParts As %List, pId As %String, Output pTaken As %Boolean) As %Status
{
    Do ##class(OcuPilot.Test.ScreenSaveTrace).Mark("taken")
    Quit ##super(pParts, pId, .pTaken)
}

ClassMethod Merge(pToolClass As %String, pFresh As %DynamicObject, pArgs As %DynamicObject, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String, Output pViolations) As %Status
{
    Do ##class(OcuPilot.Test.ScreenSaveTrace).Mark("merge")
    Quit ##super(pToolClass, pFresh, pArgs, .pPayload, .pDiff, .pUnchanged, .pProblem, .pViolations)
}

ClassMethod CheckMerged() As %Boolean
{
    Quit ''##class(OcuPilot.Test.ScreenSaveTrace).Armed("checkmerged")
}

ClassMethod Consequence(pId As %String, pPayload As %DynamicObject, pFresh As %DynamicObject, Output pConsequence As %String)
{
    Do ##class(OcuPilot.Test.ScreenSaveTrace).Mark("consequence")
    Do ##super(pId, pPayload, pFresh, .pConsequence)
}

ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pSuccess As %Integer, pId As %String, pParts As %List, pReadBack As %DynamicObject = "", pConsequence As %String = "") As %Status [ Private ]
{
    Do ##class(OcuPilot.Test.ScreenSaveTrace).Mark("answer")
    If ##class(OcuPilot.Test.ScreenSaveTrace).Armed("throwanswer") Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the answer raised an exception"))
    Quit ##super(pSC, .pViolations, pHttp, pFault, pSuccess, pId, pParts, pReadBack, pConsequence)
}

}
