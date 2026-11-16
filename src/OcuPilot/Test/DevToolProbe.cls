/// <p>Story 24.1's probe documents: the classes <code>OcuProbe241.Alpha</code> (saved, not compiled),
/// <code>OcuProbe241.Beta</code> (compiled, so its generated routine exists) and <code>OcuProbe241.Gamma</code>
/// (a compiled unit-test class), the routine <code>OcuProbe241Mac.mac</code> and the include file
/// <code>OcuProbe241Inc.inc</code>, created in a namespace by the tests that count and hash them and removed by
/// <method>Remove</method>, which names only these.</p>
/// <p>Story 24.8's pair of probe packages, <method>MakePair</method> and <method>RemovePair</method>, follow the same
/// rules for the package <code>OcuProbe248</code>.</p>
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
    Quit ..RemoveDocuments(pNamespace, ..#PACKAGE, ..#ROUTINES)
}

/// <p>Remove the package <var>pPackage</var> and the comma-separated routines <var>pRoutines</var> from
/// <var>pNamespace</var>, the classes' generated routines with them, and report any that survives.</p>
ClassMethod RemoveDocuments(pNamespace As %String, pPackage As %String, pRoutines As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do $System.OBJ.DeletePackage(pPackage, "-d")
        For tI = 1:1:$Length(pRoutines, ",") {
            Set tName = $Piece(pRoutines, ",", tI)
            If ##class(%RoutineMgr).Exists(tName) Do ##class(%RoutineMgr).Delete(tName)
        }
        Set tLeft = ""
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE Name %STARTSWITH ?", pPackage _ ".")
        While tRS.%Next() {
            Set tLeft = tLeft _ " " _ tRS.%GetData(1)
        }
        For tI = 1:1:$Length(pRoutines, ",") {
            If ##class(%RoutineMgr).Exists($Piece(pRoutines, ",", tI)) Set tLeft = tLeft _ " " _ $Piece(pRoutines, ",", tI)
        }
        Set $NAMESPACE = tOrigNS
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "probe documents survive in " _ pNamespace _ ":" _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The package <method>MakePair</method> saves.</p>
Parameter PAIRPACKAGE = "OcuProbe248";

/// <p>The routine <method>MakePair</method> saves in its first namespace only.</p>
Parameter PAIRROUTINE = "OcuProbe248Mac.mac";

/// <p>The text of <code>OcuProbe248.</code><var>pClass</var> with method body <var>pMethod</var>.</p>
ClassMethod PairText(pClass As %String, pMethod As %String) As %String
{
    Set tCRLF = $Char(13, 10)
    Quit "Class " _ ..#PAIRPACKAGE _ "." _ pClass _ " Extends %RegisteredObject" _ tCRLF _ "{" _ tCRLF _ ..Body(pClass, pMethod) _ "}" _ tCRLF
}

/// <p>Save the <code>OcuProbe248</code> documents in two namespaces: <code>Same</code> (identical) and
/// <code>Changed</code> (a different method in each) in both, <code>OnlyHere</code> and the routine
/// <code>OcuProbe248Mac.mac</code> in <var>pHere</var> only, and <code>OnlyThere</code> in <var>pThere</var> only.
/// None is compiled. The second namespace's documents are saved a tenth of a second after the first's, so a document
/// held alike carries two different times (the instance keeps a document's time to below the second).</p>
ClassMethod MakePair(pHere As %String = "USER", pThere As %String = "HSCUSTOM") As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        For tSide = 1, 2 {
            If tSide = 2 Hang 0.1
            Set tNamespace = $Select(tSide = 1: pHere, 1: pThere)
            Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(tNamespace, ..#PAIRPACKAGE _ ".Same", ..PairText("Same", "One"))
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(tNamespace, ..#PAIRPACKAGE _ ".Changed", ..PairText("Changed", $Select(tSide = 1: "Here", 1: "There")))
            If $$$ISERR(tSC) Quit
            Set tOnly = $Select(tSide = 1: "OnlyHere", 1: "OnlyThere")
            Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(tNamespace, ..#PAIRPACKAGE _ "." _ tOnly, ..PairText(tOnly, "One"))
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        Set $NAMESPACE = pHere
        Set tMac = ##class(%Routine).%New(..#PAIRROUTINE)
        Do tMac.WriteLine("OcuProbe248Mac ; probe")
        Do tMac.WriteLine(" Quit")
        Set tSC = tMac.Save()
        Set tMac = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove every <code>OcuProbe248</code> document from <var>pHere</var> and <var>pThere</var> and report any that
/// survives.</p>
ClassMethod RemovePair(pHere As %String = "USER", pThere As %String = "HSCUSTOM") As %Status
{
    Set tSC = $$$OK
    For tNamespace = pHere, pThere {
        Set tRemoveSC = ..RemoveDocuments(tNamespace, ..#PAIRPACKAGE, ..#PAIRROUTINE)
        If $$$ISERR(tRemoveSC) Set tSC = $$$ADDSC(tSC, tRemoveSC)
    }
    Quit tSC
}

}
