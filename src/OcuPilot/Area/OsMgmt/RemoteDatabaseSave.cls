/// <p>The remote database form's Save (AD-55, Story 18.16): <code>POST /remote-database</code> creates
/// one remote database through <class>OcuPilot.Screen.Tool.RemoteDatabaseCreate</class>, and
/// <code>PUT /remote-database/:id</code> re-points one through
/// <class>OcuPilot.Screen.Tool.RemoteDatabaseUpdate</class>, on <class>OcuPilot.Area.OsMgmt.DatabaseSave</class>'s
/// model: each write resolved from its tool class, its pairs asked before anything is read or sent,
/// AD-10's set asked before the port, and no proposal minted.</p>
/// <p><b>The port lists the data server at the Save</b> (AD-21's seventh case): a refusal it answers on
/// a field -- an absent or unreachable data server, a directory it does not list, its
/// <code>IRISSYS</code> directory -- is the form's own 422 on that field, and a local configuration
/// the port's 409 <parameter>OcuPilot.Api.DatabaseError.LOCAL</parameter>.</p>
Class OcuPilot.Area.OsMgmt.RemoteDatabaseSave Extends OcuPilot.Area.OsMgmt.DatabaseSave
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.RemoteDatabaseCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.RemoteDatabaseUpdate";

/// <p>The edit has one group: the re-point, written by <parameter>UPDATETOOL</parameter>.</p>
Parameter GROUPS = "remote:OcuPilot.Screen.Tool.RemoteDatabaseUpdate";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RemoteDatabaseForm";

Parameter RULES = "OcuPilot.Area.OsMgmt.RemoteDatabaseRules";

/// <p>Answer <code>PUT /remote-database/:id</code>: re-point the remote database <var>pId</var> -- one
/// path segment, decoded once here (AD-13) -- from the body's <code>Server</code> and
/// <code>Directory</code>, merged over the tool's fresh read (AD-4), and answer <code>{name,
/// readBack}</code> with 200. A key the tool does not admit is 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>; a configuration the instance does
/// not hold is 404 <parameter>OcuPilot.Api.DatabaseError.NAMEABSENT</parameter>.</p>
ClassMethod HandleUpdate(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        If '..Body(.tBody) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tName = ##class(OcuPilot.Kernel.EntityId).Decode(pId)
        Set tArgs = ##class(OcuPilot.Port.DatabasePort).Without(tBody, $ListBuild(..#IDARGUMENT))
        Do tArgs.%Set(..#IDARGUMENT, tName, "string")
        Set tGateSC = ..Gate(.tRefused, ..#UPDATETOOL, tArgs)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tPerformSC = ..Update(..#UPDATETOOL, tName, ##class(OcuPilot.Port.DatabasePort).Without(tBody, $ListBuild(..#IDARGUMENT)), .tHttp, .tFault, .tViolations, .tReadBack)
        If $$$ISERR(tPerformSC) && (+$Get(tViolations) = 0) && (+$Get(tHttp) = 404) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.DatabaseError).#REASONNAMEABSENT, ##class(OcuPilot.Api.DatabaseError).#NAMEABSENT)
            Quit
        }
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 200, $ZConvert(tName, "U"), $Get(tReadBack))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

}
