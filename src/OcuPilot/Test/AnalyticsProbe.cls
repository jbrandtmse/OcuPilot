/// <p>Test-only helper for Story 20.11's suites: probe analytics objects in <code>USER</code> that the
/// tests read through <class>OcuPilot.Port.AnalyticsPort</class>. <method>Enable</method> turns analytics on for
/// <code>USER</code>'s default web application, recording the two flags it changes; <method>Create</method> compiles
/// three source classes and four cubes, builds them, and writes a term list, a folder of folder items and two favorites;
/// <method>Remove</method> deletes all of it and restores the flags; <method>Gone</method> says whether nothing is left.</p>
/// <p>The objects are named for <parameter>PACKAGE</parameter>, <parameter>VISITS</parameter>, <parameter>CATEGORIES</parameter>,
/// <parameter>GUARDED</parameter>, <parameter>TERMLIST</parameter> and <parameter>FOLDER</parameter>. The guarded cube and the
/// guarded dashboard carry the resource <parameter>RESOURCE</parameter>.</p>
/// <p>Two sets are made on demand, by a test that needs them, and removed by <method>Remove</method> with the rest:
/// <method>CreateLinks</method> adds a pair of cubes (<parameter>LINKONE</parameter> and <parameter>LINKMANY</parameter>) whose
/// <b>guarded</b> side defines a relationship, and <method>CreateTermListTwo</method> adds a second term list with two extra fields.</p>
/// <p>The probe keeps one record, <code>^OcuPilotProbeAnalytics</code> in <code>USER</code>'s globals: the flags
/// <method>Enable</method> changed. It outlives the process that wrote it, so a run that died is cleaned up by the next one.</p>
/// <p>Story 20.33 adds the <b>grid</b> cube (<parameter>GRID</parameter>) over <parameter>GRIDROWS</parameter> deterministic rows
/// whose two dimensions give a crossjoin slow enough to cancel, and the cleanup of what an MDX query leaves: each probe cube's
/// subtree of <code>^DeepSee.Cache.Results</code>, <parameter>SPLICE</parameter>, a <code>^DeepSee.ComputedSQL</code> that names
/// a probe class and the local caches of result sets (<method>LocalCaches</method>). <method>Gone</method> checks all four.</p>
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

/// <p>The grid cube (Story 20.33): its logical name, the class that defines it, its source class and how many facts the source
/// holds.</p>
Parameter GRID = "OcuPilotProbeGrid";

Parameter GRIDCLASS = "OcuPilotProbe.Analytics.GridCube";

Parameter GRIDSOURCE = "OcuPilotProbe.Analytics.Grid";

Parameter GRIDROWS = 50000;

/// <p>The global an ask-first statement's braces increment, in <code>USER</code>: <code>^OcuPilotProbeMdxSplice(&lt;n&gt;)</code>.
/// Each test that runs such a statement takes its own subscript.</p>
Parameter SPLICE = "^OcuPilotProbeMdxSplice";

/// <p>The probe cubes' logical names, and the classes that define them.</p>
Parameter VISITS = "OcuPilotProbeVisits";

Parameter CATEGORIES = "OcuPilotProbeCategories";

Parameter GUARDED = "OcuPilotProbeGuarded";

Parameter VISITSCLASS = "OcuPilotProbe.Analytics.VisitsCube";

Parameter CATEGORIESCLASS = "OcuPilotProbe.Analytics.CategoriesCube";

Parameter GUARDEDCLASS = "OcuPilotProbe.Analytics.GuardedCube";

/// <p>The relationship the Visits cube names to the Categories cube.</p>
Parameter RELATIONSHIP = "CategoryRel";

/// <p>The calculated measure the guarded cube defines, which the vendor lists without a hidden flag.</p>
Parameter CALCULATED = "Twice";

/// <p>The resource the guarded cube and the guarded dashboard carry.</p>
Parameter RESOURCE = "%DeepSee_Admin";

/// <p>The link pair <method>CreateLinks</method> makes: <parameter>LINKMANY</parameter> carries <parameter>RESOURCE</parameter> and
/// defines the relationship <parameter>LINKREL</parameter> to <parameter>LINKONE</parameter>, which names the inverse
/// <parameter>LINKINVERSE</parameter>.</p>
Parameter LINKONE = "OcuPilotProbeLinkOne";

Parameter LINKMANY = "OcuPilotProbeLinkMany";

Parameter LINKONECLASS = "OcuPilotProbe.Analytics.LinkOneCube";

Parameter LINKMANYCLASS = "OcuPilotProbe.Analytics.LinkManyCube";

Parameter LINKREL = "OneRef";

Parameter LINKINVERSE = "ManyRefs";

/// <p>The probe term list, its field, and its keys with the value and field value of each.</p>
Parameter TERMLIST = "OcuPilotProbeTerms";

Parameter TERMFIELD = "Note";

Parameter TERMS = "k1=Alpha=first note;k2=Beta=second note;k3=Gamma=third note";

/// <p>The second term list <method>CreateTermListTwo</method> makes, its two extra fields (<code>^</code>-separated, as the vendor
/// keeps them) and its one entry: <code>key=value=first field=second field</code>.</p>
Parameter TERMLISTTWO = "OcuPilotProbeTermsTwo";

Parameter TERMFIELDSTWO = "Note^Tag";

Parameter TERMSTWO = "z1=Zed=zed note=zed tag";

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

/// <p>The text of one probe class: <code>Category</code>, <code>Visit</code>, <code>Grid</code>, <code>VisitsCube</code>,
/// <code>CategoriesCube</code>, <code>GuardedCube</code>, <code>GridCube</code>, <code>LinkOneCube</code> or <code>LinkManyCube</code>. A single quote in
/// the cube XML stands for a double one.</p>
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
    If pName = "Grid" {
        Quit tHead _ "%Persistent" _ tNL _ "{" _ tNL _
            "Property Sub As %Integer;" _ tNL _
            "Property Sub2 As %Integer;" _ tNL _
            "Property Amount As %Integer;" _ tNL _ "}" _ tNL
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
    } ElseIf pName = "GridCube" {
        Set tCube = "<cube xmlns='http://www.intersystems.com/deepsee' name='" _ ..#GRID _ "' displayName='OcuPilot probe grid' sourceClass='" _ ..#GRIDSOURCE _ "'>" _
            "<dimension name='Sub' hasAll='false'><hierarchy name='H1'><level name='Sub' sourceProperty='Sub'/></hierarchy></dimension>" _
            "<dimension name='Sub2' hasAll='false'><hierarchy name='H1'><level name='Sub2' sourceProperty='Sub2'/></hierarchy></dimension>" _
            "<measure name='Amount' sourceProperty='Amount' aggregate='SUM'/>" _
            "<listing name='Detail' fieldList='Sub,Sub2,Amount'/>" _
            "</cube>"
        Set tDepends = ..#GRIDSOURCE
    } ElseIf pName = "LinkOneCube" {
        Set tCube = "<cube xmlns='http://www.intersystems.com/deepsee' name='" _ ..#LINKONE _ "' displayName='OcuPilot probe link one' sourceClass='" _ ..#CATEGORYCLASS _ "'>" _
            "<dimension name='Label' hasAll='false'><hierarchy name='H1'><level name='Name' sourceProperty='Name'/></hierarchy></dimension>" _
            "<relationship name='" _ ..#LINKINVERSE _ "' relatedCube='" _ ..#LINKMANY _ "' cardinality='many' inverse='" _ ..#LINKREL _ "'/>" _
            "</cube>"
        Set tDepends = ..#CATEGORYCLASS
    } ElseIf pName = "LinkManyCube" {
        Set tCube = "<cube xmlns='http://www.intersystems.com/deepsee' name='" _ ..#LINKMANY _ "' displayName='OcuPilot probe link many' resource='" _ ..#RESOURCE _ "' sourceClass='" _ ..#VISITCLASS _ "'>" _
            "<dimension name='Place' hasAll='false'><hierarchy name='H1'><level name='Category' sourceProperty='Category.Name'/></hierarchy></dimension>" _
            "<relationship name='" _ ..#LINKREL _ "' sourceProperty='Category' relatedCube='" _ ..#LINKONE _ "' cardinality='one' inverse='" _ ..#LINKINVERSE _ "'/>" _
            "</cube>"
        ; The "one" side of a relationship compiles first.
        Set tDepends = ..#VISITCLASS _ "," _ ..#LINKONECLASS
    } Else {
        Set tCube = "<cube xmlns='http://www.intersystems.com/deepsee' name='" _ ..#GUARDED _ "' displayName='OcuPilot probe guarded' resource='" _ ..#RESOURCE _ "' sourceClass='" _ ..#CATEGORYCLASS _ "'>" _
            "<dimension name='Label' hasAll='false'><hierarchy name='H1'><level name='Name' sourceProperty='Name'/></hierarchy></dimension>" _
            "<calculatedMember name='" _ ..#CALCULATED _ "' dimension='Measures' valueExpression='[Measures].[%COUNT]*2'/>" _
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
        For tName = "Category", "Visit", "Grid", "VisitsCube", "CategoriesCube", "GuardedCube", "GridCube" {
            Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, ..#PACKAGE _ "." _ tName, ..ClassText(tName))
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.CompilePackage(..#PACKAGE, "ck-d")
        If $$$ISERR(tSC) Quit
        Set tSC = ..Fill()
        If $$$ISERR(tSC) Quit
        Set tSC = ..FillGrid()
        If $$$ISERR(tSC) Quit
        ; The "one" side first: building it rebuilds the cube that depends on it.
        Set tSC = ##class(%DeepSee.Utils).%BuildCube(..#CATEGORIES, 0, 0)
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(%DeepSee.Utils).%BuildCube(..#GUARDED, 0, 0)
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(%DeepSee.Utils).%BuildCube(..#GRID, 0, 0)
        If $$$ISERR(tSC) Quit
        Set tSC = ..CreateTermList()
        If $$$ISERR(tSC) Quit
        Set tSC = ..CreateFolderItems()
        If $$$ISERR(tSC) Quit
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

/// <p>Compile and build the link pair in <code>USER</code>: <parameter>LINKONE</parameter> over the Category rows, and
/// <parameter>LINKMANY</parameter> over the Visit rows, which carries <parameter>RESOURCE</parameter> and defines the relationship
/// <parameter>LINKREL</parameter> to it. It refuses, changing nothing, unless <method>Create</method> has run, because the Visit
/// rows are its source.</p>
ClassMethod CreateLinks() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tCreated = ..Reports()
        If tCreated {
            Set $NAMESPACE = ..#NAMESPACE
            Set tCreated = ##class(%Dictionary.CompiledClass).%ExistsId(..#VISITCLASS)
            Set $NAMESPACE = tOrigNS
        }
        If 'tCreated {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsProbe.CreateLinks needs the probe created in " _ ..#NAMESPACE _ ": call Enable and Create first")
            Quit
        }
        For tName = "LinkOneCube", "LinkManyCube" {
            Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, ..#PACKAGE _ "." _ tName, ..ClassText(tName))
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.Compile(..#LINKONECLASS _ "," _ ..#LINKMANYCLASS, "ck-d")
        If $$$ISERR(tSC) Quit
        ; The "one" side first: building it rebuilds the cube that depends on it.
        Set tSC = ##class(%DeepSee.Utils).%BuildCube(..#LINKONE, 0, 0)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create, in <code>USER</code>, the second term list: <parameter>TERMFIELDSTWO</parameter> as its extra fields and
/// <parameter>TERMSTWO</parameter> as its entry. <method>Remove</method> deletes it.</p>
ClassMethod CreateTermListTwo() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = ##class(%DeepSee.TermList).%CreateTermList(..#TERMLISTTWO, "OcuPilot probe terms two", ..#TERMFIELDSTWO, "", "OcuPilot probe term list with two fields")
        For tI = 1:1:$Length(..#TERMSTWO, ";") {
            If $$$ISERR(tSC) Quit
            Set tTerm = $Piece(..#TERMSTWO, ";", tI)
            Set tSC = ##class(%DeepSee.TermList).%SetValue(..#TERMLISTTWO, $Piece(tTerm, "=", 1), $Piece(tTerm, "=", 2))
            For tField = 1:1:$Length(..#TERMFIELDSTWO, "^") {
                If $$$ISERR(tSC) Quit
                Set tSC = ##class(%DeepSee.TermList).%SetValue(..#TERMLISTTWO, $Piece(tTerm, "=", 1), $Piece(tTerm, "=", 2 + tField), $Piece(..#TERMFIELDSTWO, "^", tField))
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete the second term list from <code>USER</code>; nothing happens when there is none.</p>
ClassMethod DeleteTermListTwo() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = ##class(%DeepSee.TermList).%DeleteTermList(..#TERMLISTTWO)
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

/// <p>Write the grid source's <parameter>GRIDROWS</parameter> rows, in <code>USER</code>, deterministically: row <var>i</var>
/// holds <code>Sub = i#2000</code>, <code>Sub2 = (i\7)#2000</code> and <code>Amount = i#100</code>.</p>
ClassMethod FillGrid() As %Status [ Private ]
{
    Set tSC = $$$OK
    Do $ClassMethod(..#GRIDSOURCE, "%KillExtent")
    For tI = 1:1:..#GRIDROWS {
        Set tRow = $ClassMethod(..#GRIDSOURCE, "%New")
        Set tRow.Sub = tI # 2000
        Set tRow.Sub2 = (tI \ 7) # 2000
        Set tRow.Amount = tI # 100
        Set tSC = tRow.%Save()
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

/// <p>How many result sets' local caches <code>USER</code> holds: the entries of <code>^DeepSee.Cache.LocalResults</code> other than the vendor's session
/// counter, and the entries of <code>^DeepSee.Cache.LocalAxis</code>. A result set closed in the namespace it was made in clears its own, so a count
/// that grows across a run says a result set was released elsewhere. Reads <code>USER</code> whatever namespace the caller is in.</p>
ClassMethod LocalCaches() As %Integer
{
    Set tCount = 0
    Set tKey = $Order(^|"USER"|DeepSee.Cache.LocalResults(""))
    While tKey '= "" {
        If tKey '= "session" Set tCount = tCount + 1
        Set tKey = $Order(^|"USER"|DeepSee.Cache.LocalResults(tKey))
    }
    Set tKey = $Order(^|"USER"|DeepSee.Cache.LocalAxis(""))
    While tKey '= "" {
        Set tCount = tCount + 1
        Set tKey = $Order(^|"USER"|DeepSee.Cache.LocalAxis(tKey))
    }
    Quit tCount
}

/// <p>Whether <var>pKey</var>, a subscript of <code>^DeepSee.Cache.Results</code>, names one of the probe cubes, in any case: the vendor keys the
/// cache by the cube name as the query spelled it.</p>
ClassMethod IsProbeCube(pKey As %String) As %Boolean [ Private ]
{
    Quit $ListFind($ListBuild($ZConvert(..#LINKMANY, "U"), $ZConvert(..#LINKONE, "U"), $ZConvert(..#VISITS, "U"), $ZConvert(..#CATEGORIES, "U"), $ZConvert(..#GUARDED, "U"), $ZConvert(..#GRID, "U")), $ZConvert(pKey, "U")) > 0
}

/// <p>Whether <var>pText</var>, the SQL a <code>%SEARCH</code> run leaves in <code>^DeepSee.ComputedSQL</code>, names a probe class, spelled as a class
/// (<parameter>PACKAGE</parameter>) or as the table of its generated fact class.</p>
ClassMethod NamesProbeClass(pText As %String) As %Boolean [ Private ]
{
    Quit (pText [ ..#PACKAGE) || (pText [ $Translate(..#PACKAGE, ".", "_"))
}

/// <p>Leave <code>USER</code> as found: kill the probe cubes, delete the probe classes and their extents and the probe's
/// <code>^OBJ.DSTIME</code> nodes, both term lists, the folder items and the folder, both favorites of every user and the cubes'
/// build events, then restore the two flags <method>Enable</method> recorded, read them back and kill the probe node. It works
/// whatever was created, so a run that died is cleaned up. A removal step that fails leaves its object for <method>Left</method> to
/// name; the status returned is the flags' restore or a raised error.</p>
ClassMethod Remove() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tCube = ..#LINKMANY, ..#LINKONE, ..#VISITS, ..#CATEGORIES, ..#GUARDED, ..#GRID {
            If ##class(%DeepSee.Utils).%IsDeepSeeEnabled() && ##class(%DeepSee.Utils).%CubeExists(tCube) Do ##class(%DeepSee.Utils).%KillCube(tCube, 1)
        }
        ; An MDX query leaves its result cache: %KillCube clears the axes and cells but keeps one activeChunk node per query key.
        Set tKey = $Order(^DeepSee.Cache.Results(""))
        While tKey '= "" {
            Set tNext = $Order(^DeepSee.Cache.Results(tKey))
            If ..IsProbeCube(tKey) Kill ^DeepSee.Cache.Results(tKey)
            Set tKey = tNext
        }
        ; A result set a process closed outside this namespace leaves its local cache here, keyed by the vendor's session counter.
        Set tKey = $Order(^DeepSee.Cache.LocalResults(""))
        While tKey '= "" {
            Set tNext = $Order(^DeepSee.Cache.LocalResults(tKey))
            If tKey '= "session" Kill ^DeepSee.Cache.LocalResults(tKey)
            Set tKey = tNext
        }
        Kill ^DeepSee.Cache.LocalAxis
        Set tSplice = ..#SPLICE
        Kill @tSplice
        If $Data(^DeepSee.ComputedSQL) && ..NamesProbeClass($Get(^DeepSee.ComputedSQL)) Kill ^DeepSee.ComputedSQL
        For tClass = ..#VISITCLASS, ..#CATEGORYCLASS, ..#GRIDSOURCE {
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
        Do ##class(%DeepSee.TermList).%DeleteTermList(..#TERMLISTTWO)
        For tItem = ..#PIVOT, ..#DASHBOARD, ..#GUARDEDDASHBOARD {
            Do ##class(%DeepSee.UserLibrary.Utils).%DeleteFolderItem(tItem)
        }
        Set tFolder = ##class(%DeepSee.UserLibrary.Utils).%FindFolder(..#FOLDER)
        If $IsObject(tFolder) Do ##class(%DeepSee.UserLibrary.Folder).%DeleteId(tFolder.%Id())
        Set tFolder = ""
        ; Every user's: a run that died may have written them for a user the probe node no longer names.
        Set tUser = ""
        For {
            Set tUser = $Order(^DeepSee.UserPreferences(tUser))
            If tUser = "" Quit
            Kill ^DeepSee.UserPreferences(tUser, "favorite", ..#PIVOT), ^DeepSee.UserPreferences(tUser, "favorite", ..#DANGLING)
        }
        ; CubeKey collates SQLUPPER, so a plain %STARTSWITH matches the upper-case keys.
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM %DeepSee_CubeManager.CubeEvent WHERE CubeKey %STARTSWITH ?", "OCUPILOTPROBE")
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
        ; %CubeExists reads the cube registry, which answers whether or not USER reports analytics.
        For tCube = ..#VISITS, ..#CATEGORIES, ..#GUARDED, ..#GRID, ..#LINKONE, ..#LINKMANY {
            If ##class(%DeepSee.Utils).%CubeExists(tCube) Set tLeft = tLeft _ ",cube " _ tCube
        }
        If ##class(%DeepSee.TermList).%TermListExists(..#TERMLIST) Set tLeft = tLeft _ ",term list"
        If ##class(%DeepSee.TermList).%TermListExists(..#TERMLISTTWO) Set tLeft = tLeft _ ",second term list"
        For tItem = ..#PIVOT, ..#DASHBOARD, ..#GUARDEDDASHBOARD {
            If ##class(%DeepSee.UserLibrary.Utils).%FolderItemExists(tItem) Set tLeft = tLeft _ ",folder item " _ tItem
        }
        If $IsObject(##class(%DeepSee.UserLibrary.Utils).%FindFolder(..#FOLDER)) Set tLeft = tLeft _ ",folder"
        Set tUser = ""
        For {
            Set tUser = $Order(^DeepSee.UserPreferences(tUser))
            If tUser = "" Quit
            If $Data(^DeepSee.UserPreferences(tUser, "favorite", ..#PIVOT)) || $Data(^DeepSee.UserPreferences(tUser, "favorite", ..#DANGLING)) Set tLeft = tLeft _ ",favorite of " _ tUser
        }
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %DeepSee_CubeManager.CubeEvent WHERE CubeKey %STARTSWITH ?", "OCUPILOTPROBE")
        If tRS.%Next() && (+tRS.%GetData(1) > 0) Set tLeft = tLeft _ ",build events"
        Set tPrefix = "^" _ ..#PACKAGE _ "."
        Set tGlobal = $Order(^$GLOBAL($Extract(tPrefix, 1, *-1)))
        If (tGlobal '= "") && ($Extract(tGlobal, 1, $Length(tPrefix)) = tPrefix) Set tLeft = tLeft _ ",data globals"
        If $Data(^OcuPilotProbeAnalytics) Set tLeft = tLeft _ ",probe node"
        Set tKey = $Order(^DeepSee.Cache.Results(""))
        While tKey '= "" {
            If ..IsProbeCube(tKey) Set tLeft = tLeft _ ",cache of " _ tKey
            Set tKey = $Order(^DeepSee.Cache.Results(tKey))
        }
        If ..LocalCaches() > 0 Set tLeft = tLeft _ ",local result caches"
        Set tSplice = ..#SPLICE
        If $Data(@tSplice) Set tLeft = tLeft _ ",splice node"
        If $Data(^DeepSee.ComputedSQL) && ..NamesProbeClass($Get(^DeepSee.ComputedSQL)) Set tLeft = tLeft _ ",computed sql"
        Set $NAMESPACE = tOrigNS
        If ..Reports() Set tLeft = tLeft _ ",analytics reported"
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tLeft = tLeft _ ",unreadable: " _ ex.DisplayString()
    }
    Quit $Extract(tLeft, 2, *)
}

}
