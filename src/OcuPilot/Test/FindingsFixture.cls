/// <p><class>OcuPilot.Kernel.Shell.Findings</class> over rows a test sets, for
/// <class>OcuPilot.Test.Findings</class>. Every seam answers from
/// <code>^||OcuPilotFindingsFixture</code>: a screen's gate and read, a detail object, the role rows
/// and public permissions, the clock, and a removal's verdict. A seam nobody set answers as a
/// clean instance would: the gate passes, the read has no rows, a detail call is a 404. The
/// failure log is captured rather than written.</p>
Class OcuPilot.Test.FindingsFixture Extends OcuPilot.Kernel.Shell.Findings
{

/// <p>Forget every setting and captured log call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotFindingsFixture
}

/// <p>Refuse <var>pDescriptor</var>'s gate naming <var>pPair</var>.</p>
ClassMethod SetGate(pDescriptor As %String, pPair As %String)
{
    Set ^||OcuPilotFindingsFixture("gate", pDescriptor) = pPair
}

/// <p>Answer <var>pDescriptor</var>'s read with <var>pRows</var>, cut at its cap when
/// <var>pTruncated</var>, carrying <var>pBanner</var>.</p>
ClassMethod SetRows(pDescriptor As %String, pRows As %DynamicArray, pTruncated As %Boolean = 0, pBanner As %String = "")
{
    Set tResult = {"rows": (pRows), "banner": (pBanner)}
    Do tResult.%Set("truncated", pTruncated, "boolean")
    Set ^||OcuPilotFindingsFixture("read", pDescriptor) = tResult.%ToJSON()
}

/// <p>Make <var>pDescriptor</var>'s read raise.</p>
ClassMethod SetReadThrows(pDescriptor As %String)
{
    Set ^||OcuPilotFindingsFixture("readthrows", pDescriptor) = 1
}

/// <p>Answer a detail call on <var>pEndpoint</var> for <var>pId</var> with <var>pObject</var>.</p>
ClassMethod SetDetail(pEndpoint As %String, pId As %String, pObject As %DynamicObject)
{
    Set ^||OcuPilotFindingsFixture("detail", pEndpoint, pId) = pObject.%ToJSON()
}

/// <p>Answer the effective-privilege read with <var>pRoleRows</var> and <var>pPublic</var>, or
/// with <var>pUnchecked</var>.</p>
ClassMethod SetEffective(pRoleRows As %DynamicObject, pPublic As %DynamicObject, pUnchecked As %String = "")
{
    Set ^||OcuPilotFindingsFixture("effective") = {"rows": (pRoleRows), "public": (pPublic), "unchecked": (pUnchecked)}.%ToJSON()
}

/// <p>Answer <var>pUser</var>'s removal verdict with <var>pCode</var>, <code>""</code> meaning not
/// refused. A user with no verdict set is asked of the instance.</p>
ClassMethod SetVerdict(pUser As %String, pCode As %String)
{
    Set ^||OcuPilotFindingsFixture("verdict", pUser) = pCode
}

/// <p>Fix the clock at <var>pMoment</var>, <code>$ZTimeStamp</code>-shaped.</p>
ClassMethod SetNow(pMoment As %String)
{
    Set ^||OcuPilotFindingsFixture("now") = pMoment
}

/// <p>How many failures reached the log, and the check the last one named.</p>
ClassMethod LogCalls() As %Integer
{
    Quit $Get(^||OcuPilotFindingsFixture("logcalls"), 0)
}

ClassMethod Logged() As %String
{
    Quit $Get(^||OcuPilotFindingsFixture("logged"), "")
}

ClassMethod Gate(pDescriptor As %String, Output pPair As %String) As %Status
{
    Set pPair = $Get(^||OcuPilotFindingsFixture("gate", pDescriptor), "")
    Quit $$$OK
}

ClassMethod ListRead(pDescriptor As %String, Output pResult As %DynamicObject) As %Status
{
    If $Data(^||OcuPilotFindingsFixture("readthrows", pDescriptor)) {
        Throw ##class(%Exception.General).%New("FindingsFixture", 1, , "fixture: the read of " _ pDescriptor _ " raised")
    }
    Set pResult = ##class(%DynamicObject).%FromJSON($Get(^||OcuPilotFindingsFixture("read", pDescriptor), "{""rows"":[],""truncated"":false,""banner"":""""}"))
    Quit $$$OK
}

ClassMethod Detail(pEndpoint As %String, pType As %String, pParam As %String, pId As %String, Output pObject, Output pHttpStatus As %Integer) As %Status
{
    Set pObject = ""
    If '$Data(^||OcuPilotFindingsFixture("detail", pEndpoint, pId)) {
        Set pHttpStatus = 404
        Quit $$$ERROR($$$GeneralError, "fixture: no " _ pEndpoint _ " " _ pId)
    }
    Set pHttpStatus = 200
    Set pObject = ##class(%DynamicObject).%FromJSON(^||OcuPilotFindingsFixture("detail", pEndpoint, pId))
    Quit $$$OK
}

ClassMethod EffectiveRead(pRoots As %DynamicArray, Output pRoleRows As %DynamicObject, Output pPublic As %DynamicObject, Output pUnchecked As %String) As %Status
{
    Set tSet = ##class(%DynamicObject).%FromJSON($Get(^||OcuPilotFindingsFixture("effective"), "{""rows"":{},""public"":{},""unchecked"":""""}"))
    Set pRoleRows = tSet.%Get("rows")
    Set pPublic = tSet.%Get("public")
    Set pUnchecked = tSet.%Get("unchecked")
    Quit $$$OK
}

ClassMethod RemovalVerdict(pUser As %String, Output pProhibits As %Boolean, Output pCode As %String) As %Status
{
    If '$Data(^||OcuPilotFindingsFixture("verdict", pUser)) Quit ##super(pUser, .pProhibits, .pCode)
    Set pCode = ^||OcuPilotFindingsFixture("verdict", pUser)
    Set pProhibits = (pCode '= "")
    Quit $$$OK
}

ClassMethod Now() As %String
{
    Quit $Get(^||OcuPilotFindingsFixture("now"), ##super())
}

ClassMethod LogSourceFailure(pField As %String, pException As %Exception.AbstractException)
{
    Set ^||OcuPilotFindingsFixture("logged") = pField
    Set ^||OcuPilotFindingsFixture("logcalls") = $Get(^||OcuPilotFindingsFixture("logcalls"), 0) + 1
}

}
