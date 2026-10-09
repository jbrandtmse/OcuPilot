/// <p>Story 20.20's probe documents: <class>OcuPilot.Test.ExplorerSaveProbe</class>'s classes and routines
/// under the packages <parameter>PACKAGE</parameter> and <parameter>OWNPACKAGE</parameter>, so the agent
/// create tests never share a document with the save tests. <method>NewClassText</method> and
/// <method>NewRoutineText</method> answer the whole UDL text a create proposes, header first. Created,
/// read and removed through the inherited helpers.</p>
Class OcuPilot.Test.ExplorerCreateProbe Extends OcuPilot.Test.ExplorerSaveProbe
{

Parameter PACKAGE = "OcuProbe2020";

Parameter OWNPACKAGE = "OcuPilotProbe2020";

Parameter ROUTINEPREFIX = "OcuProbe2020";

/// <p>Every routine the create tests make, hold or assert free, so <method>Remove</method> deletes each one.</p>
Parameter ROUTINES = "OcuProbe2020Mac.mac,OcuProbe2020Mac.inc,OcuProbe2020Mac.int,OcuProbe2020Inc.inc,OcuProbe2020Inc.mac,OcuProbe2020Int.int,OcuProbe2020Int.mac,OcuProbe2020Int.inc,OcuProbe2020INT.mac,OcuProbe2020Other.mac";

Parameter LOCKGLOBAL = "OcuProbe2020Lock";

/// <p>The whole UDL text of a new class <var>pName</var> (with its package): one method that answers 1,
/// and with <var>pBroken</var> also a property typed by a class that does not exist, which compiles with
/// an error.</p>
ClassMethod NewClassText(pName As %String, pBroken As %Boolean = 0) As %String
{
    Set tText = "Class " _ pName _ " Extends %RegisteredObject" _ $Char(10) _ "{" _ $Char(10) _ $Char(10)
    If pBroken Set tText = tText _ "Property Broken As " _ ..#PACKAGE _ ".NoSuchType;" _ $Char(10) _ $Char(10)
    Set tText = tText _ "ClassMethod Probe() As %Integer" _ $Char(10) _ "{" _ $Char(10) _ "    Quit 1" _ $Char(10) _ "}" _ $Char(10) _ $Char(10) _ "}"
    Quit tText
}

/// <p>The whole UDL text of a new routine or include file <var>pName</var>: a <code>ROUTINE</code> header
/// that names it, then one line of code, or for an include file one <code>#define</code>.</p>
ClassMethod NewRoutineText(pName As %String) As %String
{
    Set tBase = $Piece(pName, ".", 1)
    If $ZConvert($Piece(pName, ".", 2), "L") = "inc" Quit "ROUTINE " _ tBase _ " [Type=INC]" _ $Char(10) _ "#define OcuProbe2020Value 42"
    If $ZConvert($Piece(pName, ".", 2), "L") = "int" Quit "ROUTINE " _ tBase _ " [Type=INT]" _ $Char(10) _ " Quit"
    Quit "ROUTINE " _ tBase _ $Char(10) _ " Quit"
}

}
