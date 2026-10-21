/// <p>Test-only helper for Story 20.11's suites: probe analytics objects in <code>USER</code> that the
/// tests read through <class>OcuPilot.Port.AnalyticsPort</class>. <method>Enable</method> turns analytics on for
/// <code>USER</code>'s default web application, recording the two flags it changes; <method>Create</method> compiles
/// two source classes and three cubes, builds them, and writes a term list, a folder of folder items and two favorites;
/// <method>Remove</method> deletes all of it and restores the flags; <method>Gone</method> says whether nothing is left.</p>
/// <p>The objects are named for <parameter>PACKAGE</parameter>, <parameter>VISITS</parameter>, <parameter>CATEGORIES</parameter>,
/// <parameter>GUARDED</parameter>, <parameter>TERMLIST</parameter> and <parameter>FOLDER</parameter>. The guarded cube and the
/// guarded dashboard carry the resource <parameter>RESOURCE</parameter>.</p>
/// <p>The probe keeps one record, <code>^OcuPilotProbeAnalytics</code> in <code>USER</code>'s globals: the flags
/// <method>Enable</method> changed and the user whose favorites <method>Create</method> wrote. It outlives the process that
/// wrote it, so a run that died is cleaned up by the next one.</p>
/// <p>The vendor bookkeeping a first build creates in a namespace (<code>^DeepSee.Agents</code>, <code>Tasks</code> and
/// <code>TaskGroups</code>) is not removed: it belongs to the namespace, not to a cube.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests. Every entry point acts on
/// <code>USER</code> by explicit save and restore of the namespace, and a run needs a throwaway instance.</p>
Class OcuPilot.Test.AnalyticsProbe Extends %RegisteredObject
{

/// <p>The namespace the probe lives in.</p>
Parameter NAMESPACE = "USER";

/// <p>The package of every probe class.</p>
Parameter PACKAGE = "OcuPilotProbe.Analytics";

Parameter CATEGORYCLASS = "OcuPilotProbe.Analytics.Category";

Parameter VISITCLASS = "OcuPilotProbe.Analytics.Visit";

/// <p>The probe cubes' logical names, and the classes that define them.</p>
Parameter VISITS = "OcuPilotProbeVisits";

Parameter CATEGORIES = "OcuPilotProbeCategories";

Parameter GUARDED = "OcuPilotProbeGuarded";

Parameter VISITSCLASS = "OcuPilotProbe.Analytics.VisitsCube";

Parameter CATEGORIESCLASS = "OcuPilotProbe.Analytics.CategoriesCube";

Parameter GUARDEDCLASS = "OcuPilotProbe.Analytics.GuardedCube";

/// <p>The relationship the Visits cube names to the Categories cube.</p>
Parameter RELATIONSHIP = "CategoryRel";

/// <p>The resource the guarded cube and the guarded dashboard carry.</p>
Parameter RESOURCE = "%DeepSee_Admin";

/// <p>The probe term list, its field, and its keys with the value and field value of each.</p>
Parameter TERMLIST = "OcuPilotProbeTerms";

Parameter TERMFIELD = "Note";

Parameter TERMS = "k1=Alpha=first note;k2=Beta=second note;k3=Gamma=third note";

/// <p>The folder and the folder items in it, by full name.</p>
Parameter FOLDER = "OcuPilotProbe";

Parameter PIVOT = "OcuPilotProbe/Visits.pivot";

Parameter DASHBOARD = "OcuPilotProbe/Board.dashboard";

Parameter GUARDEDDASHBOARD = "OcuPilotProbe/Guarded.dashboard";

/// <p>A favorite that names no folder item.</p>
Parameter DANGLING = "OcuPilotProbe/Gone.pivot";

/// <p>How many facts the Visits cube holds, and how many rows the Categories source class holds.</p>
Parameter VISITROWS = 1000;

Parameter CATEGORYROWS = 5;

/// <p>The text of one probe class: <code>Category</code>, <code>Visit</code>, <code>VisitsCube</code>,
/// <code>CategoriesCube</code> or <code>GuardedCube</code>. A single quote in the cube XML stands for a double one.</p>
ClassMethod ClassText(pName As %String) As %String [ Private ]
{
    Set tNL = $Char(13, 10)
    Set tHead = "Class " _ ..#PACKAGE _ "." _ pName _ " Extends "
    If pName = "Category" {
        Quit tHead _ "%Persistent" _ tNL _ "{" _ tNL _ "Property Name As %String;" _ tNL _ "}" _ tNL
    }
    If pName = "Visit" {
        Quit tHead _ "%Persistent" _ tNL _ "{" _ tNL _ "Parameter DSTIME = ""AUTO"";" _ tNL _
            "Property Category As " _ ..#CATEGORYCLASS _ ";" _ tNL _
            "Property Day As %Date;" _ tNL _
            "Property Amount As %Numeric;" _ tNL _
            "Property Minutes As %Integer;" _ tNL _ "}" _ tNL
    }
    If pName = "CategoriesCube" {
        Set tCube = "<cube xmlns='http://www.intersystems.com/deepsee' name='" _ ..#CATEGORIES _ "' displayName='OcuPilot probe categories' sourceClass='" _ ..#CATEGORYCLASS _ "'>" _
            "<dimension name='Label' hasAll='false'><hierarchy name='H1'><level name='Name' sourceProperty='Name'/></hierarchy></dimension>" _
            "<relationship name='Visits' relatedCube='" _ ..#VISITS _ "' cardinality='many' inverse='" _ ..#RELATIONSHIP _ "'/>" _
            "</cube>"
        Set tDepends = ..#CATEGORYCLASS
    } ElseIf pName = "VisitsCube" {
        Set tCube = "<cube xmlns='http://www.intersystems.com/deepsee' name='" _ ..#VISITS _ "' displayName='OcuPilot probe visits' sourceClass='" _ ..#VISITCLASS _ "'>" _
            "<dimension name='Seen' sourceProperty='Day' type='time' hasAll='false'><hierarchy name='H1'><level name='Year' timeFunction='Year'/><level name='Month' timeFunction='MonthYear'/></hierarchy></dimension>" _
            "<dimension name='Place' hasAll='false'><hierarchy name='H1'><level name='Category' sourceProperty='Category.Name'/></hierarchy></dimension>" _
            "<measure name='Amount' sourceProperty='Amount' aggregate='SUM'/>" _
            "<measure name='Minutes' sourceProperty='Minutes' aggregate='AVG' hidden='true'/>" _
            "<listing name='Detail' fieldList='Amount,Minutes'/>" _
            "<relationship name='" _ ..#RELATIONSHIP _ "' sourceProperty='Category' relatedCube='" _ ..#CATEGORIES _ "' cardinality='one' inverse='Visits'/>" _
            "</cube>"
        ; The "one" side of a relationship compiles first.
        Set tDepends = ..#VISITCLASS _ "," _ ..#CATEGORIESCLASS
    } Else {
        Set tCube = "<cube xmlns='http://www.intersystems.com/deepsee' name='" _ ..#GUARDED _ "' displayName='OcuPilot probe guarded' resource='" _ ..#RESOURCE _ "' sourceClass='" _ ..#CATEGORYCLASS _ "'>" _
            "<dimension name='Label' hasAll='false'><hierarchy name='H1'><level name='Name' sourceProperty='Name'/></hierarchy></dimension>" _
            "</cube>"
        Set tDepends = ..#CATEGORYCLASS
    }
    Quit tHead _ "%DeepSee.CubeDefinition [ DependsOn = (" _ tDepends _ ") ]" _ tNL _ "{" _ tNL _
        "XData Cube [ XMLNamespace = ""http://www.intersystems.com/deepsee"" ]" _ tNL _ "{" _ tNL _
        $Translate(tCube, "'", """") _ tNL _ "}" _ tNL _ "}" _ tNL
}

/// <p>Whether <var>pNamespace</var> reports analytics.</p>
ClassMethod Reports() As %Boolean
{
    Quit ''##class(OcuPilot.Kernel.Shell.NamespaceFeatures).Reports("analytics", ..#NAMESPACE)
}

/// <p>The default web application of <code>USER</code>, which the two flags belong to.</p>
ClassMethod Application() As %String
{
    Quit $System.CSP.GetDefaultApp(..#NAMESPACE)
}

/// <p>Turn analytics on for <code>USER</code>: set <code>DeepSeeEnabled</code> and <code>iKnowEnabled</code> of its default
/// web application to 1, after recording the values they had in the probe node. It refuses, changing nothing, when
/// <code>USER</code> already reports analytics and the probe node is not the probe's own earlier enable.</p>
ClassMethod Enable() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tApp = ..Application()
        Set tOwn = 0
        Set $NAMESPACE = ..#NAMESPACE
        Set tOwn = ''$Data(^OcuPilotProbeAnalytics("flags"))
        Set $NAMESPACE = tOrigNS
        If ..Reports() && 'tOwn {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsProbe will not enable analytics in " _ ..#NAMESPACE _ ": it reports analytics already, and the probe did not enable it")
            Quit
        }
        If 'tOwn {
            Set $NAMESPACE = "%SYS"
            Kill tProps
            Set tSC = ##class(Security.Applications).Get(tApp, .tProps)
            Set $NAMESPACE = tOrigNS
            If $$$ISERR(tSC) Quit
            Set $NAMESPACE = ..#NAMESPACE
            Set ^OcuPilotProbeAnalytics("flags") = $ListBuild(tApp, +$Get(tProps("DeepSeeEnabled")), +$Get(tProps("iKnowEnabled")))
            Set $NAMESPACE = tOrigNS
        }
        Set $NAMESPACE = "%SYS"
        Kill tMod
        Set tMod("DeepSeeEnabled") = 1
        Set tMod("iKnowEnabled") = 1
        Set tSC = ##class(Security.Applications).Modify(tApp, .tMod)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Compile the probe classes, fill the source classes, build the cubes, and write the term list, the folder items and the
/// favorites of <var>pFavoriteUser</var> (the pivot and a favorite that names no item). It refuses, changing nothing, unless
/// <method>Enable</method> has run.</p>
ClassMethod Create(pFavoriteUser As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        If '..Reports() {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsProbe.Create needs analytics enabled in " _ ..#NAMESPACE _ ": call Enable first")
            Quit
        }
        If $Get(pFavoriteUser) = "" {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsProbe.Create needs the user whose favorites it writes")
            Quit
        }
        For tName = "Category", "Visit", "VisitsCube", "CategoriesCube", "GuardedCube" {
            Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, ..#PACKAGE _ "." _ tName, ..ClassText(tName))
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.CompilePackage(..#PACKAGE, "ck-d")
        If $$$ISERR(tSC) Quit
        Set tSC = ..Fill()
        If $$$ISERR(tSC) Quit
        ; The "one" side first: building it rebuilds the cube that depends on it.
        Set tSC = ##class(%DeepSee.Utils).%BuildCube(..#CATEGORIES, 0, 0)
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(%DeepSee.Utils).%BuildCube(..#GUARDED, 0, 0)
        If $$$ISERR(tSC) Quit
        Set tSC = ..CreateTermList()
        If $$$ISERR(tSC) Quit
        Set tSC = ..CreateFolderItems()
        If $$$ISERR(tSC) Quit
        Set ^OcuPilotProbeAnalytics("favorite") = pFavoriteUser
        For tFavorite = ..#PIVOT, ..#DANGLING {
            ; The vendor's %AddFavorite writes this node for the calling user; the probe names the user.
            Set ^DeepSee.UserPreferences(pFavoriteUser, "favorite", tFavorite) = $ZDateTime($Horolog, 3)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Write the Category rows and the Visit rows, in <code>USER</code>, deterministically.</p>
ClassMethod Fill() As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tBase = 66000
    ; A suite that deleted the probe's classes left their rows behind; the extents start empty.
    Do $ClassMethod(..#VISITCLASS, "%KillExtent")
    Do $ClassMethod(..#CATEGORYCLASS, "%KillExtent")
    For tI = 1:1:..#CATEGORYROWS {
        Set tCategory = $ClassMethod(..#CATEGORYCLASS, "%New")
        Set tCategory.Name = "Category " _ tI
        Set tSC = tCategory.%Save()
        If $$$ISERR(tSC) Quit
    }
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:..#VISITROWS {
        Set tVisit = $ClassMethod(..#VISITCLASS, "%New")
        Set tVisit.Category = $ClassMethod(..#CATEGORYCLASS, "%OpenId", (tI # ..#CATEGORYROWS) + 1)
        Set tVisit.Day = tBase + (tI # 400)
        Set tVisit.Amount = (tI # 97) + 1
        Set tVisit.Minutes = tI # 31
        Set tSC = tVisit.%Save()
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// <p>Create the probe term list in <code>USER</code>: its keys, their values, and the one extra field.</p>
ClassMethod CreateTermList() As %Status [ Private ]
{
    Set tSC = ##class(%DeepSee.TermList).%CreateTermList(..#TERMLIST, "OcuPilot probe terms", ..#TERMFIELD, "", "OcuPilot probe term list")
    For tI = 1:1:$Length(..#TERMS, ";") {
        If $$$ISERR(tSC) Quit
        Set tTerm = $Piece(..#TERMS, ";", tI)
        Set tSC = ##class(%DeepSee.TermList).%SetValue(..#TERMLIST, $Piece(tTerm, "=", 1), $Piece(tTerm, "=", 2))
        If $$$ISOK(tSC) Set tSC = ##class(%DeepSee.TermList).%SetValue(..#TERMLIST, $Piece(tTerm, "=", 1), $Piece(tTerm, "=", 3), ..#TERMFIELD)
    }
    Quit tSC
}

/// <p>Create, in <code>USER</code>, the probe folder's pivot, its dashboard and its guarded dashboard.</p>
ClassMethod CreateFolderItems() As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tPivot = ##class(%DeepSee.Dashboard.Pivot).%New()
    Set tPivot.fullName = ..#PIVOT
    Set tPivot.cubeName = ..#VISITS
    Set tPivot.title = "OcuPilot probe pivot"
    Set tPivot.owner = "_SYSTEM"
    Set tSC = tPivot.%Save()
    If $$$ISERR(tSC) Quit tSC
    Set tBoard = ##class(%DeepSee.Dashboard.Definition).%New()
    Set tBoard.fullName = ..#DASHBOARD
    Set tBoard.title = "OcuPilot probe dashboard"
    Set tBoard.owner = "_SYSTEM"
    Set tSC = tBoard.%Save()
    If $$$ISERR(tSC) Quit tSC
    Set tGuarded = ##class(%DeepSee.Dashboard.Definition).%New()
    Set tGuarded.fullName = ..#GUARDEDDASHBOARD
    Set tGuarded.title = "OcuPilot probe guarded dashboard"
    Set tGuarded.owner = "_SYSTEM"
    Set tGuarded.resource = ..#RESOURCE
    Quit tGuarded.%Save()
}

/// <p>Leave <code>USER</code> as found: kill the probe cubes, delete the probe classes and their extents and the probe's
/// <code>^OBJ.DSTIME</code> nodes, the term list, the folder items and the folder, both favorites and the cubes' build
/// events, then restore the two flags <method>Enable</method> recorded, read them back and kill the probe node. It works whatever was
/// created, so a run that died is cleaned up. The first failure is the status returned; the rest still run.</p>
ClassMethod Remove() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tCube = ..#VISITS, ..#CATEGORIES, ..#GUARDED {
            If ##class(%DeepSee.Utils).%IsDeepSeeEnabled() && ##class(%DeepSee.Utils).%CubeExists(tCube) Do ##class(%DeepSee.Utils).%KillCube(tCube, 1)
        }
        For tClass = ..#VISITCLASS, ..#CATEGORYCLASS {
            If ##class(%Dictionary.CompiledClass).%ExistsId(tClass) Do $ClassMethod(tClass, "%KillExtent")
        }
        Do $System.OBJ.DeletePackage(..#PACKAGE, "-d")
        Kill ^OBJ.DSTIME(..#VISITCLASS), ^OBJ.DSTIME(..#CATEGORYCLASS)
        ; The data globals of a class another suite deleted outlive it: kill every global named for the package.
        Set tPrefix = "^" _ ..#PACKAGE _ "."
        Set tGlobal = $Order(^$GLOBAL($Extract(tPrefix, 1, *-1)))
        While (tGlobal '= "") && ($Extract(tGlobal, 1, $Length(tPrefix)) = tPrefix) {
            Kill @tGlobal
            Set tGlobal = $Order(^$GLOBAL(tGlobal))
        }
        Do ##class(%DeepSee.TermList).%DeleteTermList(..#TERMLIST)
        For tItem = ..#PIVOT, ..#DASHBOARD, ..#GUARDEDDASHBOARD {
            Do ##class(%DeepSee.UserLibrary.Utils).%DeleteFolderItem(tItem)
        }
        Set tFolder = ##class(%DeepSee.UserLibrary.Utils).%FindFolder(..#FOLDER)
        If $IsObject(tFolder) Do ##class(%DeepSee.UserLibrary.Folder).%DeleteId(tFolder.%Id())
        Set tFolder = ""
        Set tUser = $Get(^OcuPilotProbeAnalytics("favorite"))
        If tUser '= "" Kill ^DeepSee.UserPreferences(tUser, "favorite", ..#PIVOT), ^DeepSee.UserPreferences(tUser, "favorite", ..#DANGLING)
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM %DeepSee_CubeManager.CubeEvent WHERE %SQLUPPER(CubeKey) %STARTSWITH ?", "OCUPILOTPROBE")
        Set tFlags = $Get(^OcuPilotProbeAnalytics("flags"))
        Set $NAMESPACE = tOrigNS
        If tFlags '= "" {
            Set $NAMESPACE = "%SYS"
            Kill tMod
            Set tMod("DeepSeeEnabled") = $List(tFlags, 2)
            Set tMod("iKnowEnabled") = $List(tFlags, 3)
            Set tFlagSC = ##class(Security.Applications).Modify($List(tFlags, 1), .tMod)
            ; The two flags read back as recorded, or the status says which did not.
            Kill tBack
            If $$$ISOK(tFlagSC) Set tFlagSC = ##class(Security.Applications).Get($List(tFlags, 1), .tBack)
            If $$$ISOK(tFlagSC) && ((+$Get(tBack("DeepSeeEnabled")) '= $List(tFlags, 2)) || (+$Get(tBack("iKnowEnabled")) '= $List(tFlags, 3))) Set tFlagSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsProbe: the two flags of " _ $List(tFlags, 1) _ " did not read back as recorded")
            Set $NAMESPACE = tOrigNS
            If $$$ISERR(tFlagSC) Set tSC = tFlagSC
        }
        If $$$ISOK(tSC) {
            Set $NAMESPACE = ..#NAMESPACE
            Kill ^OcuPilotProbeAnalytics
            Set $NAMESPACE = tOrigNS
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>1 when <code>USER</code> holds nothing of the probe: no probe class, cube, term list, folder item, favorite or build
/// event, no probe node, and no analytics reported.</p>
ClassMethod Gone() As %Boolean
{
    Quit ..Left() = ""
}

/// <p>What the probe left in <code>USER</code>, as a comma-separated list of the things that remain; <code>""</code> for
/// nothing. Exists so a failing <method>Gone</method> says what is left.</p>
ClassMethod Left() As %String
{
    Set tLeft = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %Dictionary.ClassDefinition WHERE Name %STARTSWITH ?", ..#PACKAGE _ ".")
        If tRS.%Next() && (+tRS.%GetData(1) > 0) Set tLeft = tLeft _ ",classes"
        If ##class(%DeepSee.Utils).%IsDeepSeeEnabled() {
            For tCube = ..#VISITS, ..#CATEGORIES, ..#GUARDED {
                If ##class(%DeepSee.Utils).%CubeExists(tCube) Set tLeft = tLeft _ ",cube " _ tCube
            }
        }
        If ##class(%DeepSee.TermList).%TermListExists(..#TERMLIST) Set tLeft = tLeft _ ",term list"
        For tItem = ..#PIVOT, ..#DASHBOARD, ..#GUARDEDDASHBOARD {
            If ##class(%DeepSee.UserLibrary.Utils).%FolderItemExists(tItem) Set tLeft = tLeft _ ",folder item " _ tItem
        }
        If $IsObject(##class(%DeepSee.UserLibrary.Utils).%FindFolder(..#FOLDER)) Set tLeft = tLeft _ ",folder"
        Set tUser = $Get(^OcuPilotProbeAnalytics("favorite"))
        If (tUser '= "") && ($Data(^DeepSee.UserPreferences(tUser, "favorite", ..#PIVOT)) || $Data(^DeepSee.UserPreferences(tUser, "favorite", ..#DANGLING))) Set tLeft = tLeft _ ",favorite"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %DeepSee_CubeManager.CubeEvent WHERE %SQLUPPER(CubeKey) %STARTSWITH ?", "OCUPILOTPROBE")
        If tRS.%Next() && (+tRS.%GetData(1) > 0) Set tLeft = tLeft _ ",build events"
        Set tPrefix = "^" _ ..#PACKAGE _ "."
        Set tGlobal = $Order(^$GLOBAL($Extract(tPrefix, 1, *-1)))
        If (tGlobal '= "") && ($Extract(tGlobal, 1, $Length(tPrefix)) = tPrefix) Set tLeft = tLeft _ ",data globals"
        If $Data(^OcuPilotProbeAnalytics) Set tLeft = tLeft _ ",probe node"
        Set $NAMESPACE = tOrigNS
        If ..Reports() Set tLeft = tLeft _ ",analytics reported"
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tLeft = tLeft _ ",unreadable: " _ ex.DisplayString()
    }
    Quit $Extract(tLeft, 2, *)
}

}
