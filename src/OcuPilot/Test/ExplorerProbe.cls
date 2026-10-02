/// <p>Story 19.2's probe documents: classes in package <parameter>PACKAGE</parameter>, classes in
/// package <parameter>OWNPACKAGE</parameter> whose names OcuPilot's self-protection refuses, and
/// routines named <parameter>ROUTINEPREFIX</parameter><code>*</code>, created in a namespace by the
/// tests that compile and delete them and removed by <method>Remove</method>, which names only these
/// and the globals whose names begin with <parameter>PACKAGE</parameter>.</p>
Class OcuPilot.Test.ExplorerProbe Extends %RegisteredObject
{

/// <p>The package every probe class is created in.</p>
Parameter PACKAGE = "OcuProbe192";

/// <p>The package of the probe classes whose names begin with <code>OcuPilot</code>, which the
/// self-protection arm refuses to compile or delete.</p>
Parameter OWNPACKAGE = "OcuPilotProbe192";

/// <p>The prefix every probe routine's name begins with.</p>
Parameter ROUTINEPREFIX = "OcuProbe192";

/// <p>The probe routines <method>Remove</method> deletes, by name.</p>
Parameter ROUTINES = "OcuProbe192Mac.mac,OcuProbe192Inc.inc";

/// <p>Save class <var>pName</var> (without <code>.cls</code>, in <parameter>PACKAGE</parameter> or
/// <parameter>OWNPACKAGE</parameter>) in
/// <var>pNamespace</var>, uncompiled: a method that answers 1, and with <var>pBroken</var> also a
/// property typed by a class that does not exist, which the compiler refuses.</p>
ClassMethod MakeClass(pNamespace As %String, pName As %String, pBroken As %Boolean = 0) As %Status
{
    If ($Piece(pName, ".", 1) '= ..#PACKAGE) && ($Piece(pName, ".", 1) '= ..#OWNPACKAGE) Quit $$$ERROR($$$GeneralError, "a probe class is in package " _ ..#PACKAGE _ " or " _ ..#OWNPACKAGE)
    Set tText = "Class " _ pName _ " Extends %RegisteredObject" _ $Char(13, 10) _ "{" _ $Char(13, 10)
    If pBroken Set tText = tText _ "Property Broken As " _ ..#PACKAGE _ ".NoSuchType;" _ $Char(13, 10)
    Set tText = tText _ "ClassMethod Probe() As %Integer" _ $Char(13, 10) _ "{" _ $Char(13, 10)
    Set tText = tText _ "    Quit 1" _ $Char(13, 10) _ "}" _ $Char(13, 10) _ "}" _ $Char(13, 10)
    Quit ##class(%Compiler.UDL.TextServices).SetTextFromString(pNamespace, pName, tText)
}

/// <p>Save routine <var>pName</var> (one of <parameter>ROUTINES</parameter>) in
/// <var>pNamespace</var>, uncompiled.</p>
ClassMethod MakeRoutine(pNamespace As %String, pName As %String) As %Status
{
    If '$ListFind($ListFromString(..#ROUTINES), pName) Quit $$$ERROR($$$GeneralError, "a probe routine is one of " _ ..#ROUTINES)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRoutine = ##class(%Routine).%New(pName)
        If $ZConvert($Piece(pName, ".", 2), "L") = "inc" {
            Do tRoutine.WriteLine("#define OcuProbe192Value 42")
        } Else {
            Do tRoutine.WriteLine($Piece(pName, ".", 1) _ " ; Story 19.2 probe")
            Do tRoutine.WriteLine(" Quit")
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

/// <p>Whether document <var>pDocument</var> is held in <var>pNamespace</var>.</p>
ClassMethod Exists(pNamespace As %String, pDocument As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tExists = ''##class(%RoutineMgr).Exists(pDocument)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tExists = 0
    }
    Quit tExists
}

/// <p>Whether class <var>pName</var> (without <code>.cls</code>) is compiled in
/// <var>pNamespace</var>.</p>
ClassMethod Compiled(pNamespace As %String, pName As %String) As %Boolean
{
    Set tCompiled = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tCompiled = ''##class(%Dictionary.CompiledClass).%ExistsId(pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCompiled = 0
    }
    Quit tCompiled
}

/// <p>Save and compile persistent class <var>pName</var> (in <parameter>PACKAGE</parameter>) in
/// <var>pNamespace</var> and store one row of it. <var>pGlobal</var> is the global the compiler
/// stores its data in, which begins with <parameter>PACKAGE</parameter>.</p>
ClassMethod MakePersistentRow(pNamespace As %String, pName As %String, Output pGlobal As %String) As %Status
{
    Set pGlobal = ""
    If $Piece(pName, ".", 1) '= ..#PACKAGE Quit $$$ERROR($$$GeneralError, "a probe class is in package " _ ..#PACKAGE)
    Set tText = "Class " _ pName _ " Extends %Persistent" _ $Char(13, 10) _ "{" _ $Char(13, 10)
    Set tText = tText _ "Property Label As %String;" _ $Char(13, 10) _ "}" _ $Char(13, 10)
    Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(pNamespace, pName, tText)
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = $System.OBJ.Compile(pName, "ck-d")
        If $$$ISOK(tSC) {
            Set tRow = $ClassMethod(pName, "%New")
            Set tRow.Label = "Story 19.2 probe"
            Set tSC = tRow.%Save()
            Set tRow = ""
        }
        If $$$ISOK(tSC) {
            Set tStorage = ##class(%Dictionary.CompiledStorage).%OpenId(pName _ "||Default")
            If $IsObject(tStorage) Set pGlobal = tStorage.DataLocation
            Set tStorage = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISOK(tSC) && ($Extract(pGlobal, 1, $Length(..#PACKAGE) + 1) '= ("^" _ ..#PACKAGE)) Set tSC = $$$ERROR($$$GeneralError, "the probe's data global is not the probe's own: " _ pGlobal)
    Quit tSC
}

/// <p>Whether global <var>pGlobal</var>, one of the probes' own, holds data in
/// <var>pNamespace</var>.</p>
ClassMethod HasData(pNamespace As %String, pGlobal As %String) As %Boolean
{
    If $Extract(pGlobal, 1, $Length(..#PACKAGE) + 1) '= ("^" _ ..#PACKAGE) Quit 0
    Set tHas = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tHas = ($Data(@pGlobal) > 0)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tHas = 0
    }
    Quit tHas
}

/// <p>Delete every probe class and routine from <var>pNamespace</var>, and every global whose name
/// begins with <parameter>PACKAGE</parameter>; a failing status when any survives.</p>
ClassMethod Remove(pNamespace As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do $System.OBJ.DeletePackage(..#PACKAGE, "-d")
        Do $System.OBJ.DeletePackage(..#OWNPACKAGE, "-d")
        For tI = 1:1:$Length(..#ROUTINES, ",") {
            Set tName = $Piece(..#ROUTINES, ",", tI)
            If ##class(%RoutineMgr).Exists(tName) Do ##class(%RoutineMgr).Delete(tName)
        }
        Set tPrefix = "^" _ ..#PACKAGE
        Set tGlobal = tPrefix
        For {
            Set tGlobal = $Order(^$GLOBAL(tGlobal))
            If (tGlobal = "") || ($Extract(tGlobal, 1, $Length(tPrefix)) '= tPrefix) Quit
            Kill @tGlobal
        }
        Set tLeft = ""
        Set tGlobal = $Order(^$GLOBAL(tPrefix))
        If (tGlobal '= "") && ($Extract(tGlobal, 1, $Length(tPrefix)) = tPrefix) Set tLeft = tLeft _ " " _ tGlobal
        For tPackage = ..#PACKAGE, ..#OWNPACKAGE {
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE Name %STARTSWITH ?", tPackage _ ".")
            While tRS.%Next() {
                Set tLeft = tLeft _ " " _ tRS.%GetData(1)
            }
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
