/// <p>The delete of one DDL mapping (Story 21.13, AD-6, AD-10, AD-51, AD-53, AD-58): remove one entry of
/// <code>Config.SqlSysDatatypes</code> or <code>Config.SqlUserDatatypes</code> through <class>OcuPilot.Port.ConfigPort</class>. DDL that names
/// the type afterwards no longer maps it. Two callers reach it: the list's row action Delete through
/// <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation.</p>
/// <p><b>It is destructive</b>: a deleted mapping cannot be restored from OcuPilot, so its card draws the destructive treatment, its row
/// action types the mapping's name, and its governance key ships disabled (AD-22). It sends no body; its fingerprint covers the mapping's
/// name and datatype, and its read-back reads the mapping gone on the port's 404. The concrete tools name an endpoint and a descriptor.</p>
Class OcuPilot.Screen.Tool.DdlMappingDelete Extends OcuPilot.Screen.Tool.ConfigSettingSet [ Abstract ]
{

Parameter WRITETYPE = "DELETE";

Parameter SENDSBODY As BOOLEAN = 0;

/// <p>Declared: a deleted mapping cannot be restored from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

Parameter SCREENACTIONS = "delete";

Parameter SCREENVALUES = "";

Parameter SCREENEMPTY = "";

/// <p>Nothing is compared: the read-back reads the mapping gone.</p>
Parameter READBACKFIELDS = "";

Parameter FINGERPRINTSUBJECT = "Name,Value";

Parameter PRECONDITIONFIELD = "Value";

/// <p>The removal rows the card shows: what the removed mapping held.</p>
Parameter REMOVALROWS = "Name,Value";

/// <p>One static sentence, pinned equal to <parameter>OcuPilot.Api.ConfigError.MAPPINGDELETE</parameter>.</p>
Parameter CONSEQUENCECODE = "CONFIG.MAPPING.DELETE";

/// <p>A delete sends no field.</p>
ClassMethod SettableFields() As %List
{
    Quit ""
}

ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 0
    Quit $$$OK
}

ClassMethod NameDescription() As %String
{
    Quit "The DDL mapping to delete, named exactly as the list reports it in its Name column. A mapping the list does not report is refused."
}

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: the name and the datatype the mapping holds. A
/// read that answered no <code>Value</code> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Value") '= "string") {
            Set pProblem = "this instance did not report the mapping, and a mapping whose state is unknown is not one to delete"
            Quit
        }
        Set pRows = ..RemovalRows(pFresh)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>A delete judges no value: the mapping is read and removed.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The static consequence of every delete.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
}

/// <p>A delete owes nothing once it has read OK.</p>
ClassMethod AfterWrite(pPort As %String, pEndpoint As %String, pIdParam As %String, pIdValue As %String, pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Quit $$$OK
}

}
