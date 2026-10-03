/// <p>Story 19.4's probe documents, created in a namespace by the tests that search them and look
/// their macros up, and removed by <method>Remove</method>, which names only these: classes in
/// package <parameter>PACKAGE</parameter> and the routines <parameter>ROUTINES</parameter>
/// names.</p>
/// <ul>
/// <li><parameter>INCLUDE</parameter> defines <code>OcuProbe194Value</code> on one line and
/// <code>OcuProbe194Multi</code> on two.</li>
/// <li><code>OcuProbe194.Parent</code> includes it and carries <parameter>NEEDLE</parameter> in its
/// description, a parameter's value and a method's comment line;
/// <code>OcuProbe194.Child</code> extends it and includes nothing; <code>OcuProbe194.Pair</code>
/// includes it in a parenthesized list.</li>
/// <li>The routine <code>OcuProbe194Mac.mac</code> includes it and carries the needle on one line and
/// the needle in lower case on another.</li>
/// <li><code>OcuProbe194.Long</code> carries <parameter>LONGNEEDLE</parameter> on one comment line
/// longer than <parameter>LONGLENGTH</parameter> characters.</li>
/// </ul>
Class OcuPilot.Test.ExplorerFindProbe Extends %RegisteredObject
{

/// <p>The package every probe class is created in.</p>
Parameter PACKAGE = "OcuProbe194";

/// <p>The probe include file's name, without its extension.</p>
Parameter INCLUDE = "OcuProbe194Inc";

/// <p>The probe routines <method>Remove</method> deletes, by name.</p>
Parameter ROUTINES = "OcuProbe194Inc.inc,OcuProbe194Mac.mac";

/// <p>The text the probes carry, in this case, on four lines, and in lower case on a fifth.</p>
Parameter NEEDLE = "OcuProbe194Needle";

/// <p>The text <code>OcuProbe194.Long</code>'s one long line begins with.</p>
Parameter LONGNEEDLE = "OcuProbe194Long";

/// <p>How many characters that line carries.</p>
Parameter LONGLENGTH As INTEGER = 1500;

/// <p>Create every probe document in <var>pNamespace</var> and compile the classes and
/// <code>OcuProbe194Mac.mac</code>.</p>
ClassMethod Make(pNamespace As %String) As %Status
{
    Set tSC = ..MakeRoutine(pNamespace, ..#INCLUDE _ ".inc", $ListBuild("#define OcuProbe194Value 42", "#define OcuProbe194Multi 1 ##continue", "  + 2"))
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..MakeRoutine(pNamespace, "OcuProbe194Mac.mac", $ListBuild("OcuProbe194Mac ; Story 19.4 probe", "#include " _ ..#INCLUDE, " ; " _ ..#NEEDLE _ " in a routine", " ; " _ $ZConvert(..#NEEDLE, "L") _ " in lower case", " Quit $$$OcuProbe194Value"))
    If $$$ISERR(tSC) Quit tSC
    Set tCRLF = $Char(13, 10)
    Set tParent = "Include " _ ..#INCLUDE _ tCRLF _ tCRLF _ "/// " _ ..#NEEDLE _ " in a description" _ tCRLF
    Set tParent = tParent _ "Class " _ ..#PACKAGE _ ".Parent Extends %RegisteredObject" _ tCRLF _ "{" _ tCRLF _ tCRLF
    Set tParent = tParent _ "Parameter Marked = """ _ ..#NEEDLE _ " in a parameter"";" _ tCRLF _ tCRLF
    Set tParent = tParent _ "ClassMethod Probe() As %Integer" _ tCRLF _ "{" _ tCRLF _ "    ; " _ ..#NEEDLE _ " in a method" _ tCRLF
    Set tParent = tParent _ "    Quit $$$OcuProbe194Value" _ tCRLF _ "}" _ tCRLF _ tCRLF _ "}" _ tCRLF
    Set tSC = ..MakeClass(pNamespace, ..#PACKAGE _ ".Parent", tParent)
    If $$$ISERR(tSC) Quit tSC
    Set tChild = "Class " _ ..#PACKAGE _ ".Child Extends " _ ..#PACKAGE _ ".Parent" _ tCRLF _ "{" _ tCRLF _ tCRLF _ "}" _ tCRLF
    Set tSC = ..MakeClass(pNamespace, ..#PACKAGE _ ".Child", tChild)
    If $$$ISERR(tSC) Quit tSC
    Set tPair = "Include (%occInclude, " _ ..#INCLUDE _ ")" _ tCRLF _ tCRLF _ "Class " _ ..#PACKAGE _ ".Pair Extends %RegisteredObject" _ tCRLF _ "{" _ tCRLF _ tCRLF _ "}" _ tCRLF
    Set tSC = ..MakeClass(pNamespace, ..#PACKAGE _ ".Pair", tPair)
    If $$$ISERR(tSC) Quit tSC
    Set tLine = "    ; " _ ..#LONGNEEDLE _ " " _ $Translate($Justify("", ..#LONGLENGTH), " ", "x")
    Set tLong = "Class " _ ..#PACKAGE _ ".Long Extends %RegisteredObject" _ tCRLF _ "{" _ tCRLF _ tCRLF
    Set tLong = tLong _ "ClassMethod Probe() As %Integer" _ tCRLF _ "{" _ tCRLF _ tLine _ tCRLF _ "    Quit 1" _ tCRLF _ "}" _ tCRLF _ tCRLF _ "}" _ tCRLF
    Set tSC = ..MakeClass(pNamespace, ..#PACKAGE _ ".Long", tLong)
    If $$$ISERR(tSC) Quit tSC
    Quit ..Compile(pNamespace, ..#PACKAGE _ ".Parent.cls," _ ..#PACKAGE _ ".Child.cls," _ ..#PACKAGE _ ".Pair.cls," _ ..#PACKAGE _ ".Long.cls,OcuProbe194Mac.mac")
}

/// <p>Save class <var>pName</var> (in <parameter>PACKAGE</parameter>) in <var>pNamespace</var> from
/// <var>pText</var>, uncompiled.</p>
ClassMethod MakeClass(pNamespace As %String, pName As %String, pText As %String) As %Status
{
    If $Piece(pName, ".", 1) '= ..#PACKAGE Quit $$$ERROR($$$GeneralError, "a probe class is in package " _ ..#PACKAGE)
    Quit ##class(%Compiler.UDL.TextServices).SetTextFromString(pNamespace, pName, pText)
}

/// <p>Save routine <var>pName</var> (one of <parameter>ROUTINES</parameter>) in
/// <var>pNamespace</var> with the lines of <var>pLines</var>, uncompiled.</p>
ClassMethod MakeRoutine(pNamespace As %String, pName As %String, pLines As %List) As %Status
{
    If '$ListFind($ListFromString(..#ROUTINES), pName) Quit $$$ERROR($$$GeneralError, "a probe routine is one of " _ ..#ROUTINES)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRoutine = ##class(%Routine).%New(pName)
        Do tRoutine.Clear()
        For tI = 1:1:$ListLength(pLines) {
            Do tRoutine.WriteLine($List(pLines, tI))
        }
        Set tSC = tRoutine.Save()
        Set tRoutine = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Compile the documents <var>pList</var> names, comma-separated, in <var>pNamespace</var>.</p>
ClassMethod Compile(pNamespace As %String, pList As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = $System.OBJ.CompileList(pList, "ck-d")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete every probe class and routine from <var>pNamespace</var>; a failing status when any
/// survives.</p>
ClassMethod Remove(pNamespace As %String) As %Status
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
