/// <p>The privileged routine applications' rules (AD-39, AD-55, Story 18.31):
/// <class>OcuPilot.Area.WebApp.DocDbAppRules</class> over an application keyed by its name alone and answering
/// <class>OcuPilot.Api.RoutineAppError</class>'s codes. The one rule set
/// <class>OcuPilot.Screen.Tool.RoutineAppCreate</class> and <class>OcuPilot.Screen.Tool.RoutineAppUpdate</class> apply at
/// the mint and the confirm and <class>OcuPilot.Area.WebApp.RoutineAppSave</class> applies at the Save, every condition
/// before any <code>PUT</code>, and the editor's form read (<method>HandleForm</method>).</p>
/// <p><b>The rules are OcuPilot's own.</b> The vendor stores a name or a description over its length as a logged 500
/// and a resource it does not list as given (measured at Story 18.31's plan), so every condition is decided here. A name
/// is not empty and at most 64 characters; the settings are the Doc DB rules'.</p>
Class OcuPilot.Area.WebApp.RoutineAppRules Extends OcuPilot.Area.WebApp.DocDbAppRules
{

/// <p>The screen whose declared pairs gate the form read (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RoutineAppForm";

/// <p>The tool whose port and endpoint the form read asks (AD-52).</p>
Parameter UPDATETOOL = "OcuPilot.Screen.Tool.RoutineAppUpdate";

Parameter ERRORCLASS = "OcuPilot.Api.RoutineAppError";

Parameter NAMESPACED As BOOLEAN = 0;

/// <p>Whether <var>pName</var> is an application name: not empty and at most
/// <parameter>OcuPilot.Api.RoutineAppError.NAMEMAX</parameter> characters.</p>
ClassMethod IsName(pName As %String) As %Boolean
{
    Quit ($Length(pName) >= 1) && ($Length(pName) <= $Parameter(..#ERRORCLASS, "NAMEMAX"))
}

/// <p>Whether an application of any kind holds the name <var>pName</var>, in <var>pTaken</var>, read through
/// <var>pPortClass</var> as the caller with the update tool's own endpoint and read type (AD-52): the read answers an
/// object for a routine application, and 404 <parameter>OcuPilot.Api.RoutineAppError.TYPE</parameter> for a name another
/// kind of application holds. Any other 404 is free, and any other failed read is an error status.
/// <var>pNamespace</var> is ignored.</p>
ClassMethod Taken(pPortClass As %String, pNamespace As %String, pName As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    Kill tQuery
    Set tQuery($ClassMethod(..#UPDATETOOL, "IdParam")) = pName
    Set tSC = $ClassMethod(pPortClass, "Invoke", $ClassMethod(..#UPDATETOOL, "Endpoint"), $ClassMethod(..#UPDATETOOL, "ReadType"), .tQuery, "", .tRead, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If +$Get(tHttp) '= 404 Quit tSC
        Set pTaken = ($IsObject($Get(tFault)) && (tFault.code = $Parameter(..#ERRORCLASS, "TYPE")))
        Quit $$$OK
    }
    Set pTaken = ($IsObject($Get(tRead)) && tRead.%IsA("%Library.DynamicObject"))
    Quit $$$OK
}

/// <p>Render a failed read of an application: 404 <parameter>OcuPilot.Api.RoutineAppError.TYPE</parameter> for a name
/// another kind of application holds, otherwise <method>OcuPilot.Area.WebApp.DocDbAppRules.RenderRead</method>'s
/// answer.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If (+$Get(pHttpStatus) = 404) && $IsObject($Get(pFault)) && (pFault.code = $Parameter(..#ERRORCLASS, "TYPE")) {
        Quit ##class(OcuPilot.Api.Error).Render(404, pFault.error, pFault.reason, pFault.code)
    }
    Quit ##super(pSC, pHttpStatus, pFault)
}

}
