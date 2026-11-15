/// <p>Story 24.1's probe documents: the classes <code>OcuProbe241.Alpha</code> (saved, not compiled),
/// <code>OcuProbe241.Beta</code> (compiled, so its generated routine exists) and <code>OcuProbe241.Gamma</code>
/// (a compiled unit-test class), the routine <code>OcuProbe241Mac.mac</code> and the include file
/// <code>OcuProbe241Inc.inc</code>, created in a namespace by the tests that count and hash them and removed by
/// <method>Remove</method>, which names only these.</p>
Class OcuPilot.Test.DevToolProbe Extends %RegisteredObject
{

/// <p>The package every probe class is in.</p>
Parameter PACKAGE = "OcuProbe241";

/// <p>The probe routines <method>Remove</method> deletes, by name.</p>
Parameter ROUTINES = "OcuProbe241Mac.mac,OcuProbe241Inc.inc";

/// <p>The probe classes, without <code>.cls</code>.</p>
Parameter CLASSES = "OcuProbe241.Alpha,OcuProbe241.Beta,OcuProbe241.Gamma";

/// <p>The lines of a probe class's body: a comment, code and a blank line, so each kind is counted.</p>
ClassMethod Body(pName As %String, pMethod As %String) As %String
{
    Set tCRLF = $Char(13, 10)
    Quit "/// A doc comment." _ tCRLF _ "Method " _ pMethod _ "() As %Integer" _ tCRLF _ "{" _ tCRLF _ "    ; a comment line" _ tCRLF _ "    Set tValue = 1" _ tCRLF _ tCRLF _ "    Quit tValue" _ tCRLF _ "}" _ tCRLF
}

/// <p>Save every probe document in <var>pNamespace</var>, and compile <code>Beta</code> and
/// <code>Gamma</code> there.</p>
ClassMethod Make(pNamespace As %String = "USER") As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tCRLF = $Char(13, 10)
        For tClass = "Alpha", "Beta", "Gamma" {
            Set tBase = $Select(tClass = "Gamma": "%UnitTest.TestCase", 1: "%RegisteredObject")
            Set tMethod = $Select(tClass = "Gamma": "TestOne", 1: "One")
            Set tText = "Class " _ ..#PACKAGE _ "." _ tClass _ " Extends " _ tBase _ tCRLF _ "{" _ tCRLF _ ..Body(tClass, tMethod) _ "}" _ tCRLF
            Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(pNamespace, ..#PACKAGE _ "." _ tClass, tText)
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        Set $NAMESPACE = pNamespace
        Set tSC = $System.OBJ.Compile(..#PACKAGE _ ".Beta," _ ..#PACKAGE _ ".Gamma", "ck-d")
        If $$$ISOK(tSC) {
            Set tMac = ##class(%Routine).%New("OcuProbe241Mac.mac")
            Do tMac.WriteLine("OcuProbe241Mac ; probe")
            Do tMac.WriteLine(" ; a comment")
            Do tMac.WriteLine(" Quit")
            Do tMac.WriteLine("")
            Set tSC = tMac.Save()
            Set tMac = ""
        }
        If $$$ISOK(tSC) {
            Set tInc = ##class(%Routine).%New("OcuProbe241Inc.inc")
            Do tInc.WriteLine("#define OcuProbe241Value 42")
            Set tSC = tInc.Save()
            Set tInc = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The text of class <var>pClass</var> (a probe class, without <code>.cls</code>) in <var>pNamespace</var> as the
/// instance holds it, one line to a node with the count at <code>pLines(0)</code>.</p>
ClassMethod ClassLines(pNamespace As %String, pClass As %String, Output pLines) As %Status
{
    Kill pLines
    Quit ##class(%Compiler.UDL.TextServices).GetTextAsArray(pNamespace, pClass, .pLines)
}

/// <p>The lines of routine <var>pName</var> (a probe routine) as the instance holds them: its header line, then the
/// lines <method>Make</method> wrote.</p>
ClassMethod RoutineLines(pName As %String, Output pLines) As %Status
{
    Kill pLines
    If pName = "OcuProbe241Mac.mac" {
        Set pLines(1) = "ROUTINE OcuProbe241Mac"
        Set pLines(2) = "OcuProbe241Mac ; probe"
        Set pLines(3) = " ; a comment"
        Set pLines(4) = " Quit"
        Set pLines(5) = ""
        Set pLines(0) = 5
    } Else {
        Set pLines(1) = "ROUTINE OcuProbe241Inc [Type=INC]"
        Set pLines(2) = "#define OcuProbe241Value 42"
        Set pLines(0) = 2
    }
    Quit $$$OK
}

/// <p>Remove every probe document from <var>pNamespace</var>, the classes' generated routines with them, and report any
/// that survives.</p>
ClassMethod Remove(pNamespace As %String = "USER") As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do $System.OBJ.DeletePackage(..#PACKAGE, "-d")
        For tI = 1:1:$Length(..#ROUTINES, ",") {
            Set tName = $Piece(..#ROUTINES, ",", tI)
            If ##class(%RoutineMgr).Exists(tName) Do ##class(%RoutineMgr).Delete(tName)
        }
        Set tLeft = ""
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE Name %STARTSWITH ?", ..#PACKAGE _ ".")
        While tRS.%Next() {
            Set tLeft = tLeft _ " " _ tRS.%GetData(1)
        }
        For tI = 1:1:$Length(..#ROUTINES, ",") {
            If ##class(%RoutineMgr).Exists($Piece(..#ROUTINES, ",", tI)) Set tLeft = tLeft _ " " _ $Piece(..#ROUTINES, ",", tI)
        }
        Set $NAMESPACE = tOrigNS
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "probe documents survive in " _ pNamespace _ ":" _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
