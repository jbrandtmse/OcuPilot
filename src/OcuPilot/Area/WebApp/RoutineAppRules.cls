/// <p>The privileged routine applications' rules (AD-39, AD-55, Story 18.31):
/// <class>OcuPilot.Area.WebApp.DocDbAppRules</class> over an application keyed by its name alone and answering
/// <class>OcuPilot.Api.RoutineAppError</class>'s codes. The one rule set
/// <class>OcuPilot.Screen.Tool.RoutineAppCreate</class> and <class>OcuPilot.Screen.Tool.RoutineAppUpdate</class> apply at
/// the mint and the confirm and <class>OcuPilot.Area.WebApp.RoutineAppSave</class> applies at the Save, every condition
/// before any <code>PUT</code>, and the editor's form read (<method>HandleForm</method>).</p>
/// <p><b>The rules are OcuPilot's own.</b> The vendor stores a name or a description over its length as a logged 500
/// and a resource it does not list as given (measured at Story 18.31's plan), so every condition is decided here. A name
/// is not empty and at most 64 characters; the settings are the Doc DB rules'.</p>
/// <p><b>The two lists are judged by the same rules on every caller</b> (<method>Check</method>): the application roles
/// and matching roles by <method>OcuPilot.Area.WebApp.Create.MatchRolesViolation</method>, the routines by
/// <method>RoutinesViolation</method>. A list that equals the fresh read's is never judged, so a stored entry is not
/// refused for being as it is.</p>
Class OcuPilot.Area.WebApp.RoutineAppRules Extends OcuPilot.Area.WebApp.DocDbAppRules
{

/// <p>The screen whose declared pairs gate the form read (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RoutineAppForm";

/// <p>The tool whose port and endpoint the form read asks (AD-52).</p>
Parameter UPDATETOOL = "OcuPilot.Screen.Tool.RoutineAppUpdate";

Parameter ERRORCLASS = "OcuPilot.Api.RoutineAppError";

Parameter NAMESPACED As BOOLEAN = 0;

/// <p>The three members of one routine entry, in the order the instance lists them.</p>
Parameter ENTRYNAME = "RoutineOrClass";

Parameter ENTRYDB = "Db";

Parameter ENTRYTYPE = "Type";

/// <p>The two entry types the instance stores.</p>
Parameter ENTRYTYPES = "Routine,Class";

/// <p>The settings' rules (<method>OcuPilot.Area.WebApp.DocDbAppRules.Check</method>), then, for an update, each list
/// <var>pBody</var> sends: judged when <var>pFull</var> is 0, and when it is 1 only if it differs from
/// <var>pFresh</var>'s. A broken application-roles list is
/// <parameter>OcuPilot.Api.Error.WEBAPPMATCHROLESSHAPE</parameter> or
/// <parameter>OcuPilot.Api.Error.WEBAPPMATCHROLESUNKNOWN</parameter> on <code>MatchRoles</code>, and a broken routines
/// list <parameter>OcuPilot.Api.RoutineAppError.ROUTINES</parameter> on <code>Routines</code>, once. A look-up that
/// cannot be made is an error status, never a pass.</p>
ClassMethod Check(pNamespace As %String, pName As %String, pBody As %DynamicObject, pFresh As %DynamicObject, pMode As %String, pPortClass As %String, Output pViolations, pFull As %Boolean = 1) As %Status
{
    Set tSC = ##super(pNamespace, pName, pBody, pFresh, pMode, pPortClass, .pViolations, pFull)
    If $$$ISERR(tSC) || (pMode '= "update") || '$IsObject(pBody) Quit tSC
    Try {
        Set tFresh = $Select($IsObject(pFresh): pFresh, 1: {})
        If ..Judged(pBody, tFresh, "MatchRoles", pFull) {
            Set tSC = ##class(OcuPilot.Area.WebApp.Create).MatchRolesViolation(pBody, .pViolations)
            If $$$ISERR(tSC) Quit
        }
        If ..Judged(pBody, tFresh, "Routines", pFull) Set tSC = ..RoutinesViolation(pBody, .pViolations)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the list <var>pField</var> of <var>pBody</var> is judged: it is sent, and either <var>pFull</var> is 0 or
/// it is not the one <var>pFresh</var> holds.</p>
ClassMethod Judged(pBody As %DynamicObject, pFresh As %DynamicObject, pField As %String, pFull As %Boolean) As %Boolean
{
    Set tType = pBody.%GetTypeOf(pField)
    If tType = "unassigned" Quit 0
    If 'pFull Quit 1
    If pFresh.%GetTypeOf(pField) '= tType Quit 1
    If (tType '= "array") && (tType '= "object") Quit 1
    Quit pBody.%Get(pField).%ToJSON() '= pFresh.%Get(pField).%ToJSON()
}

/// <p>Add <parameter>OcuPilot.Api.RoutineAppError.ROUTINES</parameter> to <var>pViolations</var>, once, when
/// <var>pBody</var>'s <code>Routines</code> is not an array of entries that are each exactly three strings: a
/// routine or class name that is not empty and holds neither <code>,</code> nor <code>:</code> (the classic page's
/// stored entry joins its parts with them), a database <method>OcuPilot.Port.AdminPort.DatabaseNames</method> lists
/// and a type, <parameter>ENTRYTYPES</parameter>. A database list that cannot be read is an error status.</p>
ClassMethod RoutinesViolation(pBody As %DynamicObject, ByRef pViolations) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tBad = (pBody.%GetTypeOf("Routines") '= "array")
        If 'tBad {
            Set tSC = ##class(OcuPilot.Port.AdminPort).DatabaseNames(.tDatabases)
            If $$$ISERR(tSC) Quit
            Set tIterator = pBody.%Get("Routines").%GetIterator()
            While tIterator.%GetNext(.tIndex, .tEntry) {
                If '..EntryValid(tEntry, tDatabases) {
                    Set tBad = 1
                    Quit
                }
            }
        }
        If tBad Do ..Add(.pViolations, "Routines", $Parameter(..#ERRORCLASS, "ROUTINES"))
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pEntry</var> is one routine entry <method>RoutinesViolation</method> admits; <var>pDatabases</var>
/// is the list of database names the instance defines.</p>
ClassMethod EntryValid(pEntry As %DynamicObject, pDatabases As %List) As %Boolean
{
    If '$IsObject(pEntry) || 'pEntry.%IsA("%Library.DynamicObject") Quit 0
    Set tCount = 0
    Set tKeys = pEntry.%GetIterator()
    While tKeys.%GetNext(.tKey) {
        Set tCount = tCount + 1
    }
    If tCount '= 3 Quit 0
    If (pEntry.%GetTypeOf(..#ENTRYNAME) '= "string") || (pEntry.%GetTypeOf(..#ENTRYDB) '= "string") || (pEntry.%GetTypeOf(..#ENTRYTYPE) '= "string") Quit 0
    Set tName = pEntry.%Get(..#ENTRYNAME)
    If (tName = "") || (tName [ ",") || (tName [ ":") Quit 0
    If '$ListFind(pDatabases, pEntry.%Get(..#ENTRYDB)) Quit 0
    Quit ''$ListFind($ListFromString(..#ENTRYTYPES), pEntry.%Get(..#ENTRYTYPE))
}

/// <p>Add <code>row.MatchRoles</code> and <code>row.Routines</code> to the form read of an existing application, each
/// as <var>pFresh</var> holds it, and to the answer <var>pBody</var> <code>roles</code>, the instance's roles as
/// <code>[{name, privileged}]</code> (<method>OcuPilot.Area.WebApp.FormRules.Roles</method>), and
/// <code>databases</code>, the names <method>OcuPilot.Port.AdminPort.DatabaseNames</method> lists.</p>
ClassMethod FormRead(pFresh As %DynamicObject, pRow As %DynamicObject, pBody As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Try {
        For tField = "MatchRoles", "Routines" {
            Set tList = []
            If pFresh.%GetTypeOf(tField) = "array" Set tList = ##class(%DynamicAbstractObject).%FromJSON(pFresh.%Get(tField).%ToJSON())
            Do pRow.%Set(tField, tList)
        }
        Set tSC = ##class(OcuPilot.Area.WebApp.FormRules).Roles(.tRoles)
        If $$$ISERR(tSC) Quit
        Do pBody.%Set("roles", tRoles)
        Set tSC = ##class(OcuPilot.Port.AdminPort).DatabaseNames(.tNames)
        If $$$ISERR(tSC) Quit
        Set tDatabases = []
        For tI = 1:1:$ListLength(tNames) Do tDatabases.%Push($List(tNames, tI))
        Do pBody.%Set("databases", tDatabases)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

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
