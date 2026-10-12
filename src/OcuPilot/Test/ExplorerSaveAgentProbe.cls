/// <p>Story 20.21's probe documents: <class>OcuPilot.Test.ExplorerSaveProbe</class>'s classes and routines
/// under the packages <parameter>PACKAGE</parameter> and <parameter>OWNPACKAGE</parameter>, so the agent
/// save tests never share a document with the person-save tests. Created, read and removed through the
/// inherited helpers; <method>Wide</method> writes a class of many lines for the card-width refusal.</p>
Class OcuPilot.Test.ExplorerSaveAgentProbe Extends OcuPilot.Test.ExplorerSaveProbe
{
Parameter PACKAGE = "OcuProbe2021";
Parameter OWNPACKAGE = "OcuPilotProbe2021";
Parameter ROUTINEPREFIX = "OcuProbe2021";
Parameter ROUTINES = "OcuProbe2021Mac.mac,OcuProbe2021Inc.inc";
Parameter LOCKGLOBAL = "OcuProbe2021Lock";

/// <p>Write class <var>pName</var> in <var>pNamespace</var> with <var>pLines</var> lines
/// <code>Set x&lt;n&gt; = &lt;n&gt;</code>, n counted from 1, inside its one method and before
/// <code>Quit 1</code>, so the class is <var>pLines</var> + 9 lines long.</p>
ClassMethod Wide(pNamespace As %String, pName As %String, pLines As %Integer) As %Status
{
    Set tText = "Class " _ pName _ " Extends %RegisteredObject" _ $Char(10) _ "{" _ $Char(10) _ $Char(10)
    Set tText = tText _ "ClassMethod Probe() As %Integer" _ $Char(10) _ "{" _ $Char(10)
    For tI = 1:1:pLines {
        Set tText = tText _ "    Set x" _ tI _ " = " _ tI _ $Char(10)
    }
    Set tText = tText _ "    Quit 1" _ $Char(10) _ "}" _ $Char(10) _ $Char(10) _ "}" _ $Char(10)
    Quit ##class(%Compiler.UDL.TextServices).SetTextFromString(pNamespace, pName, tText, $Char(10))
}

}
