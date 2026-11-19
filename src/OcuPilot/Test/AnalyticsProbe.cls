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
/// <p>Story 20.34 adds <method>ChangeVisits</method> (changes that many Visit rows, which the Visits cube's <code>DSTIME</code> records),
/// <method>CreateHidden</method> and <method>RemoveHidden</method> (a cube whose resource <parameter>HIDDENRESOURCE</parameter> no
/// principal of the cube manager holds), and the cleanup of what a build leaves: the build tracking and statistics nodes of each probe
/// cube, and the source classes' update node. <method>Gone</method> checks the hidden cube and that residue.</p>
/// <p>Story 24.12 adds the quality measures: <method>CreateQualityMeasures</method> saves and compiles four measure classes in the probe's package (compiled, refused, linked and
/// disabled), <method>CreateEdgeQualityMeasures</method> the edge measures (no subject area, a dangling link), <method>CreateTwinQualityMeasure</method> a second class declaring
/// the compiled measure's name, which <method>RemoveTwinQualityMeasure</method> deletes, and <method>RemoveQualityMeasures</method> deletes them all with their <code>^DeepSee.QMsrs</code> nodes. <method>Remove</method> calls it and <method>Left</method> checks those nodes.</p>
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

/// <p>The hidden cube (Story 20.34) made on demand by <method>CreateHidden</method>: its logical name, its class and the resource it
/// carries, which grants no public permission and which the cube manager's pairs do not include.</p>
Parameter HIDDEN = "OcuPilotProbeHidden";

Parameter HIDDENCLASS = "OcuPilotProbe.Analytics.HiddenCube";

Parameter HIDDENRESOURCE = "%DeepSee_Architect";

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

/// <p>The listing groups <method>CreateListingGroups</method> makes in <code>USER</code>, each with the class that holds it (Story 24.11). The first
/// is compiled over the Visits cube and holds two listings, the second names a cube that does not exist and so is saved but not compiled, the third
/// carries <parameter>HIDDENRESOURCE</parameter> on the group, the fourth is disabled, and the fifth
/// (<method>CreateBrokenListingGroup</method>) holds an attribute value the model refuses, so the vendor reads it as no group.</p>
Parameter LISTGROUP = "OcuPilotProbeListings";

Parameter LISTGROUPCLASS = "OcuPilotProbe.Analytics.ListingGroup";

Parameter LISTGROUPSAVED = "OcuPilotProbeListingsSaved";

Parameter LISTGROUPSAVEDCLASS = "OcuPilotProbe.Analytics.ListingGroupSaved";

Parameter LISTGROUPHIDDEN = "OcuPilotProbeListingsHidden";

Parameter LISTGROUPHIDDENCLASS = "OcuPilotProbe.Analytics.ListingGroupHidden";

Parameter LISTGROUPOFF = "OcuPilotProbeListingsOff";

Parameter LISTGROUPOFFCLASS = "OcuPilotProbe.Analytics.ListingGroupOff";

Parameter LISTGROUPBROKEN = "OcuPilotProbeListingsBroken";

Parameter LISTGROUPBROKENCLASS = "OcuPilotProbe.Analytics.ListingGroupBroken";

/// <p>What the listing group write tests (Story 24.11, Batch 2) name: their groups start with <parameter>LISTGROUPWRITE</parameter>, their classes with
/// <parameter>LISTGROUPWRITECLASS</parameter> and their listings with <parameter>LISTINGWRITE</parameter>, so <method>RemoveListingGroups</method> and
/// <method>Left</method> find whatever a failed test left.</p>
Parameter LISTGROUPWRITE = "OcuPilotProbeLGW";

Parameter LISTGROUPWRITECLASS = "OcuProbeLGW.Analytics.LGW";

/// <p>The prefix of the classes the write tests save directly, bypassing the port, whose names begin with <code>OcuPilot</code> so the writes' refusal of OcuPilot's own code
/// can be shown against a group that exists. <method>RemoveListingGroups</method> and <method>Left</method> cover it as they cover <parameter>LISTGROUPWRITECLASS</parameter>.</p>
Parameter LISTGROUPOWNCLASS = "OcuPilotLGW.Analytics.LGW";

Parameter LISTINGWRITE = "LGW";

/// <p>The class <method>CreateTwinListingGroup</method> saves: it names the compiled group's name over a cube that does not exist, so its compile is refused, and its
/// class name sorts before the compiled group's.</p>
Parameter LISTGROUPTWINCLASS = "OcuPilotProbe.Analytics.AListingGroupTwin";

/// <p>The class <method>CreateTwinListingGroup</method> saves when it is asked for the late twin: the same group name as the early twin, and a class name that sorts after the compiled group's.</p>
Parameter LISTGROUPTWINLATECLASS = "OcuPilotProbe.Analytics.ZListingGroupTwin";

/// <p>The cube the saved listing group names and the SQL the compiled group's custom listing runs.</p>
Parameter LISTGROUPNOCUBE = "OcuPilotProbeNoSuchCube";

Parameter LISTGROUPSQL = "SELECT ID FROM OcuPilotProbe_Analytics.Visit";

/// <p>What the quality measure tests (Story 24.12) name: the catalog and set every probe measure carries, each measure's name and the class that declares it. The
/// subject area of each is <parameter>VISITS</parameter>. <method>RemoveQualityMeasures</method> and <method>Left</method> find whatever a failed test left.</p>
Parameter QMCATALOG = "OcuPilotProbe";

Parameter QMSET = "Quality";

/// <p>The measure whose class compiles: two groups, one disabled element, one documentation item.</p>
Parameter QMCOMPILED = "OcuPilotProbe/Quality/Compiled";

Parameter QMCOMPILEDCLASS = "OcuPilotProbe.Analytics.QMCompiled";

/// <p>The measure whose expression names a group it does not hold: its compile is refused and its name is registered.</p>
Parameter QMREFUSED = "OcuPilotProbe/Quality/Refused";

Parameter QMREFUSEDCLASS = "OcuPilotProbe.Analytics.QMRefused";

/// <p>The measure linked to <parameter>QMCOMPILED</parameter>, with a caption of its own and no group.</p>
Parameter QMLINKED = "OcuPilotProbe/Quality/Linked";

Parameter QMLINKEDCLASS = "OcuPilotProbe.Analytics.QMLinked";

/// <p>The disabled measure: its class compiles and the vendor lists it with no name.</p>
Parameter QMOFF = "OcuPilotProbe/Quality/Off";

Parameter QMOFFCLASS = "OcuPilotProbe.Analytics.QMOff";

/// <p>The classes <method>CreateTwinQualityMeasure</method> saves: each declares <parameter>QMCOMPILED</parameter>'s name, and their class names sort before and after the compiled measure's.</p>
Parameter QMTWINCLASS = "OcuPilotProbe.Analytics.AQMTwin";

Parameter QMTWINLATECLASS = "OcuPilotProbe.Analytics.ZQMTwin";

/// <p>The edge measures <method>CreateEdgeQualityMeasures</method> saves: one whose subject area names no cube, and a measure linked to a master whose class is deleted afterwards (the
/// master's name and class are <parameter>QMMASTER</parameter> and <parameter>QMMASTERCLASS</parameter>, which exist only while the link is made).</p>
Parameter QMMISSINGAREA = "OcuPilotProbeNoSuchArea";

Parameter QMNOAREA = "OcuPilotProbe/Quality/NoArea";

Parameter QMNOAREACLASS = "OcuPilotProbe.Analytics.QMNoArea";

Parameter QMMASTER = "OcuPilotProbe/Quality/Master";

Parameter QMMASTERCLASS = "OcuPilotProbe.Analytics.QMMaster";

Parameter QMDANGLING = "OcuPilotProbe/Quality/Dangling";

Parameter QMDANGLINGCLASS = "OcuPilotProbe.Analytics.QMDangling";

/// <p>What the quality measure write tests (Story 24.12, Batch 2) name: their measures' catalog and their classes' package start with <parameter>QMWRITE</parameter>
/// (<parameter>QMWRITECLASS</parameter> for the classes they save), and the classes they save directly to show a write refuse OcuPilot's own code start with
/// <parameter>QMWRITEOWNCLASS</parameter> in any letter case. <method>RemoveQualityMeasures</method> and <method>Left</method> cover every class and registry node under them.</p>
Parameter QMWRITE = "OcuProbeQMW";

Parameter QMWRITECLASS = "OcuProbeQMW.Analytics.QMW";

Parameter QMWRITEOWNCLASS = "OcuPilotQMW.Analytics.QMW";

/// <p>The same three names for the tests of the element and documentation writes (Story 24.12, Batch 3): <method>RemoveQualityMeasures</method>, <method>KillQualityMeasureWriteNodes</method> and
/// <method>Left</method> cover them as they cover <parameter>QMWRITE</parameter>'s.</p>
Parameter QMPART = "OcuProbeQMP";

Parameter QMPARTCLASS = "OcuProbeQMP.Analytics.QMP";

Parameter QMPARTOWNCLASS = "OcuPilotQMP.Analytics.QMP";

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
    } ElseIf pName = "HiddenCube" {
        Set tCube = "<cube xmlns='http://www.intersystems.com/deepsee' name='" _ ..#HIDDEN _ "' displayName='OcuPilot probe hidden' resource='" _ ..#HIDDENRESOURCE _ "' sourceClass='" _ ..#CATEGORYCLASS _ "'>" _
            "<dimension name='Label' hasAll='false'><hierarchy name='H1'><level name='Name' sourceProperty='Name'/></hierarchy></dimension>" _
            "</cube>"
        Set tDepends = ..#CATEGORYCLASS
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

/// <p>Change <var>pCount</var> Visit rows in <code>USER</code>, saving each so that the Visits cube's <code>DSTIME</code> records the
/// change: the cube then has <var>pCount</var> changes to synchronize.</p>
ClassMethod ChangeVisits(pCount As %Integer) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tI = 1:1:pCount {
            Set tVisit = $ClassMethod(..#VISITCLASS, "%OpenId", tI)
            If '$IsObject(tVisit) {
                Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsProbe.ChangeVisits found no Visit row " _ tI)
                Quit
            }
            Set tVisit.Amount = tVisit.Amount + 1
            Set tSC = tVisit.%Save()
            Set tVisit = ""
            If $$$ISERR(tSC) Quit
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Compile and build the hidden cube in <code>USER</code>: <parameter>HIDDEN</parameter> over the Category rows, carrying
/// <parameter>HIDDENRESOURCE</parameter>. It refuses, changing nothing, unless <method>Create</method> has run.
/// <method>RemoveHidden</method> and <method>Remove</method> delete it.</p>
ClassMethod CreateHidden() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tCreated = ..Reports()
        If tCreated {
            Set $NAMESPACE = ..#NAMESPACE
            Set tCreated = ##class(%Dictionary.CompiledClass).%ExistsId(..#CATEGORYCLASS)
            Set $NAMESPACE = tOrigNS
        }
        If 'tCreated {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsProbe.CreateHidden needs the probe created in " _ ..#NAMESPACE _ ": call Enable and Create first")
            Quit
        }
        Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, ..#HIDDENCLASS, ..ClassText("HiddenCube"))
        If $$$ISERR(tSC) Quit
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.Compile(..#HIDDENCLASS, "ck-d")
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(%DeepSee.Utils).%BuildCube(..#HIDDEN, 0, 0, 0, 0, 0)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete the hidden cube from <code>USER</code>: its facts, its definition class and its build events and tracking; nothing
/// happens when there is none.</p>
ClassMethod RemoveHidden() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        If ##class(%DeepSee.Utils).%IsDeepSeeEnabled() && ##class(%DeepSee.Utils).%CubeExists(..#HIDDEN) Do ##class(%DeepSee.Utils).%KillCube(..#HIDDEN, 1)
        If ##class(%Dictionary.CompiledClass).%ExistsId(..#HIDDENCLASS) Do $System.OBJ.Delete(..#HIDDENCLASS, "-d")
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM %DeepSee_CubeManager.CubeEvent WHERE CubeKey = ?", $ZConvert(..#HIDDEN, "U"))
        Do ..ForgetBuilds()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Kill, in the current namespace, what a build leaves for a probe cube or a probe source class: the cube's nodes of the build
/// tracking, the build statistics and the per-process update tracking, and the source classes' update node. The vendor's counters stay.</p>
ClassMethod ForgetBuilds() [ Private ]
{
    For tCube = ..#LINKMANY, ..#LINKONE, ..#VISITS, ..#CATEGORIES, ..#GUARDED, ..#GRID, ..#HIDDEN {
        Set tIndex = $ZConvert(tCube, "U")
        Kill ^IRIS.Temp.DeepSeeTracking($Namespace, tIndex)
        Kill ^IRIS.Temp.DeepSeeBuildStats($Namespace, tIndex)
        Set tJob = ""
        For {
            Set tJob = $Order(^IRIS.Temp.CubeManagerUpdateTracking(tJob))
            If tJob = "" Quit
            Kill ^IRIS.Temp.CubeManagerUpdateTracking(tJob, tIndex)
        }
    }
    For tClass = ..#VISITCLASS, ..#CATEGORYCLASS, ..#GRIDSOURCE {
        Kill ^DeepSee.Update("classes", tClass)
    }
}

/// <p>Whether a build left a node for a probe cube or a probe source class, as <method>ForgetBuilds</method> names them, in the current
/// namespace.</p>
ClassMethod BuildsLeft() As %Boolean [ Private ]
{
    Set tLeft = 0
    For tCube = ..#LINKMANY, ..#LINKONE, ..#VISITS, ..#CATEGORIES, ..#GUARDED, ..#GRID, ..#HIDDEN {
        Set tIndex = $ZConvert(tCube, "U")
        If $Data(^IRIS.Temp.DeepSeeTracking($Namespace, tIndex)) || $Data(^IRIS.Temp.DeepSeeBuildStats($Namespace, tIndex)) Set tLeft = 1
        Set tJob = ""
        For {
            Set tJob = $Order(^IRIS.Temp.CubeManagerUpdateTracking(tJob))
            If tJob = "" Quit
            If $Data(^IRIS.Temp.CubeManagerUpdateTracking(tJob, tIndex)) Set tLeft = 1
        }
    }
    For tClass = ..#VISITCLASS, ..#CATEGORYCLASS, ..#GRIDSOURCE {
        If $Data(^DeepSee.Update("classes", tClass)) Set tLeft = 1
    }
    Quit tLeft
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

/// <p>The class text of the listing group <var>pWhich</var> (<code>compiled</code>, <code>saved</code>, <code>hidden</code>, <code>off</code>,
/// <code>twin</code> or <code>broken</code>): a class extending <class>%DeepSee.ListingGroupDefinition</class> whose <code>Listings</code> XData holds the group. A single
/// quote in the XML stands for a double one.</p>
ClassMethod ListingGroupText(pWhich As %String) As %String [ Private ]
{
    Set tNL = $Char(13, 10)
    Set tNS = "xmlns='http://www.intersystems.com/deepsee/listinggroup'"
    Set tDepends = ""
    If pWhich = "compiled" {
        Set tClass = ..#LISTGROUPCLASS
        Set tDepends = " [ DependsOn = " _ ..#VISITSCLASS _ " ]"
        Set tXML = "<listingGroup " _ tNS _ " name='" _ ..#LISTGROUP _ "' displayName='OcuPilot probe listings' description='Two listings over the Visits cube' targetCubes='" _ ..#VISITS _ "' defaultResource='%DeepSee_Portal'>" _
            "<listing name='ByAmount' displayName='By amount' description='Amounts and minutes' listingType='table' fieldList='Amount,Minutes' formatList='color:red^' orderBy='Amount DESC' " _
            "joinInfo='{&quot;joins&quot;:{&quot;Category&quot;:&quot;LEFT JOIN OcuPilotProbe_Analytics.Category c ON c.ID = Category&quot;},&quot;joinAlias&quot;:{&quot;Category&quot;:&quot;c&quot;}}'/>" _
            "<listing name='CustomSql' displayName='Custom SQL' description='Runs its own query' sql='" _ ..#LISTGROUPSQL _ "' selectMode='1' resource='%DeepSee_Admin'/>" _
            "</listingGroup>"
    } ElseIf pWhich = "saved" {
        Set tClass = ..#LISTGROUPSAVEDCLASS
        Set tXML = "<listingGroup " _ tNS _ " name='" _ ..#LISTGROUPSAVED _ "' targetCubes='" _ ..#LISTGROUPNOCUBE _ "'>" _
            "<listing name='Pending' fieldList='Amount' disabled='true'/>" _
            "</listingGroup>"
    } ElseIf pWhich = "hidden" {
        Set tClass = ..#LISTGROUPHIDDENCLASS
        Set tDepends = " [ DependsOn = " _ ..#VISITSCLASS _ " ]"
        Set tXML = "<listingGroup " _ tNS _ " name='" _ ..#LISTGROUPHIDDEN _ "' targetCubes='" _ ..#VISITS _ "' resource='" _ ..#HIDDENRESOURCE _ "'>" _
            "<listing name='Secret' fieldList='Amount'/>" _
            "</listingGroup>"
    } ElseIf pWhich = "off" {
        Set tClass = ..#LISTGROUPOFFCLASS
        Set tDepends = " [ DependsOn = " _ ..#VISITSCLASS _ " ]"
        Set tXML = "<listingGroup " _ tNS _ " name='" _ ..#LISTGROUPOFF _ "' targetCubes='" _ ..#VISITS _ "' disabled='true'>" _
            "<listing name='Idle' fieldList='Minutes'/>" _
            "</listingGroup>"
    } ElseIf (pWhich = "twin") || (pWhich = "twinlate") {
        Set tClass = $Select(pWhich = "twin": ..#LISTGROUPTWINCLASS, 1: ..#LISTGROUPTWINLATECLASS)
        Set tXML = "<listingGroup " _ tNS _ " name='" _ ..#LISTGROUP _ "' targetCubes='" _ ..#LISTGROUPNOCUBE _ "'>" _
            "<listing name='Twin' fieldList='Amount'/>" _
            "</listingGroup>"
    } Else {
        Set tClass = ..#LISTGROUPBROKENCLASS
        Set tXML = "<listingGroup " _ tNS _ " name='" _ ..#LISTGROUPBROKEN _ "' targetCubes='" _ ..#VISITS _ "' disabled='perhaps'/>"
    }
    Quit "Class " _ tClass _ " Extends %DeepSee.ListingGroupDefinition" _ tDepends _ tNL _ "{" _ tNL _
        "XData Listings [ XMLNamespace = ""http://www.intersystems.com/deepsee/listinggroup"" ]" _ tNL _ "{" _ tNL _
        $Translate(tXML, "'", """") _ tNL _ "}" _ tNL _ "}" _ tNL
}

/// <p>Save the probe's listing group classes in <code>USER</code> and compile each: the compiled group, the saved group (its compile is refused for a missing
/// target cube), the group that carries <parameter>HIDDENRESOURCE</parameter> and the disabled group. It refuses, changing nothing, unless
/// <method>Create</method> has run, because the Visits cube is the target. A compile that is refused for the saved group is the point of that group, not a failure.
/// <method>RemoveListingGroups</method> deletes them.</p>
ClassMethod CreateListingGroups() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tCreated = ..Reports()
        If tCreated {
            Set $NAMESPACE = ..#NAMESPACE
            Set tCreated = ##class(%DeepSee.Utils).%CubeExists(..#VISITS)
            Set $NAMESPACE = tOrigNS
        }
        If 'tCreated {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsProbe.CreateListingGroups needs the probe created in " _ ..#NAMESPACE _ ": call Enable and Create first")
            Quit
        }
        For tWhich = "compiled", "saved", "hidden", "off" {
            Set tClass = $Case(tWhich, "compiled": ..#LISTGROUPCLASS, "saved": ..#LISTGROUPSAVEDCLASS, "hidden": ..#LISTGROUPHIDDENCLASS, : ..#LISTGROUPOFFCLASS)
            Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, tClass, ..ListingGroupText(tWhich))
            If $$$ISERR(tSC) Quit
            Set $NAMESPACE = ..#NAMESPACE
            Set tCompile = $System.OBJ.Compile(tClass, "ck-d")
            Set $NAMESPACE = tOrigNS
            If (tWhich '= "saved") && $$$ISERR(tCompile) {
                Set tSC = tCompile
                Quit
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Save the probe's broken listing group in <code>USER</code>: a class whose <code>Listings</code> XData is well-formed XML that the model refuses
/// (<code>disabled</code> is not a boolean). It is saved and its compile is attempted, and refused. <method>RemoveListingGroups</method> deletes it.</p>
ClassMethod CreateBrokenListingGroup() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, ..#LISTGROUPBROKENCLASS, ..ListingGroupText("broken"))
        If $$$ISERR(tSC) Quit
        Set $NAMESPACE = ..#NAMESPACE
        Do $System.OBJ.Compile(..#LISTGROUPBROKENCLASS, "ck-d")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Save a twin listing group in <code>USER</code>: a second class that names the compiled group's name, its class name sorting before the compiled group's
/// or, when <var>pLate</var> is true, after it. Its compile is attempted and refused, so the vendor lists two saved classes under that name and compiles one.
/// <method>RemoveTwinListingGroup</method> and <method>RemoveListingGroups</method> delete it.</p>
ClassMethod CreateTwinListingGroup(pLate As %Boolean = 0) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tClass = $Select(pLate: ..#LISTGROUPTWINLATECLASS, 1: ..#LISTGROUPTWINCLASS)
        Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, tClass, ..ListingGroupText($Select(pLate: "twinlate", 1: "twin")))
        If $$$ISERR(tSC) Quit
        Set $NAMESPACE = ..#NAMESPACE
        Do $System.OBJ.Compile(tClass, "ck-d")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete both twin listing groups' classes from <code>USER</code>; nothing happens when they are not there.</p>
ClassMethod RemoveTwinListingGroup() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tClass = ..#LISTGROUPTWINCLASS, ..#LISTGROUPTWINLATECLASS {
            If ##class(%Dictionary.ClassDefinition).%ExistsId(tClass) Do $System.OBJ.Delete(tClass, "-d")
            Kill ^DeepSee.ListingGroups("classes", tClass)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete the probe's listing group classes from <code>USER</code>, which also removes what their compile registered, and kill what is left of the
/// probe groups' registry nodes; nothing happens when there are none.</p>
ClassMethod RemoveListingGroups() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tClass = ..#LISTGROUPCLASS, ..#LISTGROUPSAVEDCLASS, ..#LISTGROUPHIDDENCLASS, ..#LISTGROUPOFFCLASS, ..#LISTGROUPBROKENCLASS, ..#LISTGROUPTWINCLASS, ..#LISTGROUPTWINLATECLASS {
            If ##class(%Dictionary.ClassDefinition).%ExistsId(tClass) Do $System.OBJ.Delete(tClass, "-d")
        }
        For tGroup = ..#LISTGROUP, ..#LISTGROUPSAVED, ..#LISTGROUPHIDDEN, ..#LISTGROUPOFF, ..#LISTGROUPBROKEN {
            Kill ^DeepSee.ListingGroups("groups", $ZConvert(tGroup, "U"))
        }
        For tClass = ..#LISTGROUPCLASS, ..#LISTGROUPSAVEDCLASS, ..#LISTGROUPHIDDENCLASS, ..#LISTGROUPOFFCLASS, ..#LISTGROUPBROKENCLASS, ..#LISTGROUPTWINCLASS, ..#LISTGROUPTWINLATECLASS {
            Kill ^DeepSee.ListingGroups("classes", tClass)
        }
        For tCube = ..#VISITS, ..#CATEGORIES, ..#LISTGROUPNOCUBE {
            Set tListing = ""
            For {
                Set tListing = $Order(^DeepSee.ListingGroups("cubes", $ZConvert(tCube, "U"), "listing", tListing))
                If tListing = "" Quit
                If $ListFind($ListBuild("ByAmount", "CustomSql", "Pending", "Secret", "Idle", "Twin"), tListing) || ($Extract(tListing, 1, $Length(..#LISTINGWRITE)) = ..#LISTINGWRITE) Kill ^DeepSee.ListingGroups("cubes", $ZConvert(tCube, "U"), "listing", tListing)
            }
        }
        ; The write tests' groups and classes, whatever a failed test left of them.
        For tPrefix = ..#LISTGROUPWRITECLASS, ..#LISTGROUPOWNCLASS {
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE Name %STARTSWITH ?", tPrefix)
            While tRS.%Next() {
                Do $System.OBJ.Delete(tRS.%GetData(1), "-d")
            }
        }
        Set tName = $Order(^DeepSee.ListingGroups("groups", $ZConvert(..#LISTGROUPWRITE, "U")), -1)
        For {
            Set tName = $Order(^DeepSee.ListingGroups("groups", tName))
            If $Extract(tName, 1, $Length(..#LISTGROUPWRITE)) '= $ZConvert(..#LISTGROUPWRITE, "U") Quit
            Kill ^DeepSee.ListingGroups("groups", tName)
        }
        For tPrefix = ..#LISTGROUPWRITECLASS, ..#LISTGROUPOWNCLASS {
            Set tName = $Order(^DeepSee.ListingGroups("classes", tPrefix), -1)
            For {
                Set tName = $Order(^DeepSee.ListingGroups("classes", tName))
                If $Extract(tName, 1, $Length(tPrefix)) '= tPrefix Quit
                Kill ^DeepSee.ListingGroups("classes", tName)
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The class text of the quality measure <var>pWhich</var> (<code>compiled</code>, <code>refused</code>, <code>linked</code>, <code>off</code>, <code>noarea</code>,
/// <code>master</code>, <code>dangling</code>, <code>twin</code> or <code>twinlate</code>): a class extending <class>%DeepSee.QualityMeasure.QualityMeasure</class> whose <code>QualityMeasure</code> XData holds the measure. A single quote
/// in the XML stands for a double one.</p>
ClassMethod QualityMeasureText(pWhich As %String) As %String [ Private ]
{
    Set tNL = $Char(13, 10)
    Set tNS = "http://www.intersystems.com/deepsee/qualityMeasure"
    Set tHead = "<qualityMeasure xmlns='" _ tNS _ "' catalog='" _ ..#QMCATALOG _ "' set='" _ ..#QMSET _ "' "
    If pWhich = "compiled" {
        Set tClass = ..#QMCOMPILEDCLASS
        Set tXML = tHead _ "id='Compiled' caption='OcuPilot probe measure' description='Visits that ran long' subjectArea='" _ ..#VISITS _ "' expression='[Long]/[Everyone]' published='true' format='#.##' href='https://example.invalid/measure'>" _
            "<group name='Long' caption='Long stays' description='Visits over the limit'>" _
            "<element name='Over30' caption='Over 30 minutes' mdx='{[Minutes].&amp;[30]}'/>" _
            "<element name='Retired' caption='Retired rule' mdx='{[Minutes].&amp;[99]}' disabled='true'/>" _
            "</group>" _
            "<group name='Everyone' caption='All visits' description='Every visit'>" _
            "<element name='AllVisits' caption='All visits' mdx='{[Minutes].Members}'/>" _
            "</group>" _
            "<meta name='Purpose' caption='Purpose' section='Overview'>Counts the long visits &amp; their share.</meta>" _
            "</qualityMeasure>"
    } ElseIf pWhich = "refused" {
        Set tClass = ..#QMREFUSEDCLASS
        Set tXML = tHead _ "id='Refused' caption='Names a missing group' subjectArea='" _ ..#VISITS _ "' expression='[Num]/[Missing]' published='false'>" _
            "<group name='Num' caption='Numerator'><element name='One' mdx='{[Minutes].&amp;[1]}'/></group>" _
            "<group name='Spare' caption='Spare group' description='Holds no element' disabled='true'/>" _
            "<meta name='Draft' caption='Draft note' section='Notes' disabled='true'>Not yet reviewed.</meta>" _
            "</qualityMeasure>"
    } ElseIf pWhich = "linked" {
        Set tClass = ..#QMLINKEDCLASS
        Set tXML = tHead _ "id='Linked' caption='Follows the compiled measure' description='Linked' linkedTo='" _ ..#QMCOMPILED _ "' subjectArea='" _ ..#VISITS _ "' expression='1'/>"
    } ElseIf pWhich = "off" {
        Set tClass = ..#QMOFFCLASS
        Set tXML = tHead _ "id='Off' caption='Disabled' subjectArea='" _ ..#VISITS _ "' expression='[Long]/[Everyone]' disabled='true'/>"
    } ElseIf pWhich = "noarea" {
        Set tClass = ..#QMNOAREACLASS
        Set tXML = tHead _ "id='NoArea' caption='Names no cube' subjectArea='" _ ..#QMMISSINGAREA _ "' expression='[Only]'>" _
            "<group name='Only' caption='Only group'><element name='One' mdx='{[Minutes].&amp;[3]}'/></group>" _
            "</qualityMeasure>"
    } ElseIf pWhich = "master" {
        Set tClass = ..#QMMASTERCLASS
        Set tXML = tHead _ "id='Master' caption='Master of the dangling link' subjectArea='" _ ..#VISITS _ "' expression='[Only]'>" _
            "<group name='Only' caption='Only group'><element name='One' mdx='{[Minutes].&amp;[4]}'/></group>" _
            "</qualityMeasure>"
    } ElseIf pWhich = "dangling" {
        Set tClass = ..#QMDANGLINGCLASS
        Set tXML = tHead _ "id='Dangling' caption='Follows a deleted master' linkedTo='" _ ..#QMMASTER _ "' subjectArea='" _ ..#VISITS _ "' expression='1'/>"
    } Else {
        Set tClass = $Select(pWhich = "twin": ..#QMTWINCLASS, 1: ..#QMTWINLATECLASS)
        Set tXML = tHead _ "id='Compiled' caption='Twin of the compiled measure' subjectArea='" _ ..#VISITS _ "' expression='[Only]'>" _
            "<group name='Only' caption='Only group'><element name='Twin' mdx='{[Minutes].&amp;[2]}'/></group>" _
            "</qualityMeasure>"
    }
    Quit "Class " _ tClass _ " Extends %DeepSee.QualityMeasure.QualityMeasure" _ tNL _ "{" _ tNL _
        "XData QualityMeasure [ XMLNamespace = ""http://www.intersystems.com/deepsee/qualityMeasure"" ]" _ tNL _ "{" _ tNL _
        $Translate(tXML, "'", """") _ tNL _ "}" _ tNL _ "}" _ tNL
}

/// <p>Save the probe's quality measure classes in <code>USER</code> and compile each, the compiled measure first because the linked one names it: the compiled
/// measure, the measure whose compile is refused (its name is registered anyway), the linked measure and the disabled one, which the vendor lists with no name. A compile
/// that is refused for the second is the point of that measure, not a failure. <method>RemoveQualityMeasures</method> deletes them.</p>
ClassMethod CreateQualityMeasures() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        For tWhich = "compiled", "refused", "linked", "off" {
            Set tClass = $Case(tWhich, "compiled": ..#QMCOMPILEDCLASS, "refused": ..#QMREFUSEDCLASS, "linked": ..#QMLINKEDCLASS, : ..#QMOFFCLASS)
            Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, tClass, ..QualityMeasureText(tWhich))
            If $$$ISERR(tSC) Quit
            Set $NAMESPACE = ..#NAMESPACE
            Set tCompile = $System.OBJ.Compile(tClass, "ck-d")
            Set $NAMESPACE = tOrigNS
            If (tWhich '= "refused") && $$$ISERR(tCompile) {
                Set tSC = tCompile
                Quit
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Save the edge quality measures in <code>USER</code>: a measure whose subject area names no cube, and a measure linked to a master that is then deleted, so the link points at
/// no measure. All three compile before the master is deleted. <method>RemoveQualityMeasures</method> deletes them.</p>
ClassMethod CreateEdgeQualityMeasures() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        For tWhich = "noarea", "master", "dangling" {
            Set tClass = $Case(tWhich, "noarea": ..#QMNOAREACLASS, "master": ..#QMMASTERCLASS, : ..#QMDANGLINGCLASS)
            Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, tClass, ..QualityMeasureText(tWhich))
            If $$$ISERR(tSC) Quit
            Set $NAMESPACE = ..#NAMESPACE
            Set tSC = $System.OBJ.Compile(tClass, "ck-d")
            Set $NAMESPACE = tOrigNS
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        Set $NAMESPACE = ..#NAMESPACE
        Do $System.OBJ.Delete(..#QMMASTERCLASS, "-d")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Save a twin quality measure in <code>USER</code>: a second class that declares the compiled measure's name, its class name sorting before the compiled measure's
/// or, when <var>pLate</var> is true, after it. It compiles and the vendor lists it, but its name stays registered to the compiled measure's class.
/// <method>RemoveTwinQualityMeasure</method> and <method>RemoveQualityMeasures</method> delete it.</p>
ClassMethod CreateTwinQualityMeasure(pLate As %Boolean = 0) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tClass = $Select(pLate: ..#QMTWINLATECLASS, 1: ..#QMTWINCLASS)
        Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, tClass, ..QualityMeasureText($Select(pLate: "twinlate", 1: "twin")))
        If $$$ISERR(tSC) Quit
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.Compile(tClass, "ck-d")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete both twin quality measures' classes from <code>USER</code>; nothing happens when they are not there. The registered measure's nodes stay.</p>
ClassMethod RemoveTwinQualityMeasure() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tClass = ..#QMTWINCLASS, ..#QMTWINLATECLASS {
            If ##class(%Dictionary.ClassDefinition).%ExistsId(tClass) Do $System.OBJ.Delete(tClass, "-d")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete the probe's quality measure classes from <code>USER</code>, the twins first, and kill what is left of the
/// probe measures' registry nodes; nothing happens when there are none.</p>
ClassMethod RemoveQualityMeasures() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tClass = ..#QMTWINCLASS, ..#QMTWINLATECLASS, ..#QMLINKEDCLASS, ..#QMREFUSEDCLASS, ..#QMOFFCLASS, ..#QMCOMPILEDCLASS, ..#QMDANGLINGCLASS, ..#QMMASTERCLASS, ..#QMNOAREACLASS {
            If ##class(%Dictionary.ClassDefinition).%ExistsId(tClass) Do $System.OBJ.Delete(tClass, "-d")
            Kill ^DeepSee.QMsrs("qmsrClasses", tClass)
        }
        For tName = ..#QMCOMPILED, ..#QMREFUSED, ..#QMLINKED, ..#QMOFF, ..#QMNOAREA, ..#QMMASTER, ..#QMDANGLING {
            Kill ^DeepSee.QMsrs("qmsrNames", $ZConvert(tName, "U")), ^DeepSee.QMsrs("cubes", $ZConvert(..#VISITS, "U"), $ZConvert(tName, "U")), ^DeepSee.QMsrs("cubes", $ZConvert(..#QMMISSINGAREA, "U"), $ZConvert(tName, "U"))
        }
        ; The write tests' measures and classes, whatever a failed test left of them, in any letter case.
        For tPrefix = ..#QMWRITE _ ".", ..#QMWRITEOWNCLASS, ..#QMPART _ ".", ..#QMPARTOWNCLASS {
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE UPPER(Name) %STARTSWITH ?", $ZConvert(tPrefix, "U"))
            While tRS.%Next() {
                Do $System.OBJ.Delete(tRS.%GetData(1), "-d")
            }
        }
        Do ..KillQualityMeasureWriteNodes(1)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The registry nodes of the write tests' measures and classes, in the namespace the process is in: the names that start with <parameter>QMWRITE</parameter> and the classes that start with
/// <parameter>QMWRITE</parameter> or <parameter>QMWRITEOWNCLASS</parameter>'s package, compared without regard to case. With <var>pKill</var> each is killed; the count found is answered.</p>
ClassMethod KillQualityMeasureWriteNodes(pKill As %Boolean) As %Integer
{
    Set tCount = 0
    Set tNamePrefixes = $ListBuild($ZConvert(..#QMWRITE, "U") _ "/", $ZConvert(..#QMPART, "U") _ "/")
    Set tClassPrefixes = $ListBuild($ZConvert(..#QMWRITE, "U") _ ".", $ZConvert($Piece(..#QMWRITEOWNCLASS, ".", 1), "U") _ ".", $ZConvert(..#QMPART, "U") _ ".", $ZConvert($Piece(..#QMPARTOWNCLASS, ".", 1), "U") _ ".")
    Set tName = ""
    For {
        Set tName = $Order(^DeepSee.QMsrs("qmsrNames", tName))
        If tName = "" Quit
        If ..QMNameMarked(tName, tNamePrefixes) {
            Set tCount = tCount + 1
            If pKill Kill ^DeepSee.QMsrs("qmsrNames", tName)
        }
    }
    Set tClass = ""
    For {
        Set tClass = $Order(^DeepSee.QMsrs("qmsrClasses", tClass))
        If tClass = "" Quit
        Set tUpper = $ZConvert(tClass, "U")
        For tAt = 1:1:$ListLength(tClassPrefixes) {
            Set tPrefix = $List(tClassPrefixes, tAt)
            If $Extract(tUpper, 1, $Length(tPrefix)) '= tPrefix Continue
            Set tCount = tCount + 1
            If pKill Kill ^DeepSee.QMsrs("qmsrClasses", tClass)
            Quit
        }
    }
    Set tArea = ""
    For {
        Set tArea = $Order(^DeepSee.QMsrs("cubes", tArea))
        If tArea = "" Quit
        Set tName = ""
        For {
            Set tName = $Order(^DeepSee.QMsrs("cubes", tArea, tName))
            If tName = "" Quit
            If ..QMNameMarked(tName, tNamePrefixes) {
                Set tCount = tCount + 1
                If pKill Kill ^DeepSee.QMsrs("cubes", tArea, tName)
            }
        }
    }
    Quit tCount
}

/// <p>1 when the registry name <var>pName</var> starts with one of the upper-case catalog prefixes <var>pPrefixes</var>.</p>
ClassMethod QMNameMarked(pName As %String, pPrefixes As %List) As %Boolean
{
    Set tMarked = 0
    For tAt = 1:1:$ListLength(pPrefixes) {
        If $Extract(pName, 1, $Length($List(pPrefixes, tAt))) = $List(pPrefixes, tAt) Set tMarked = 1
    }
    Quit tMarked
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
    Quit $ListFind($ListBuild($ZConvert(..#LINKMANY, "U"), $ZConvert(..#LINKONE, "U"), $ZConvert(..#VISITS, "U"), $ZConvert(..#CATEGORIES, "U"), $ZConvert(..#GUARDED, "U"), $ZConvert(..#GRID, "U"), $ZConvert(..#HIDDEN, "U")), $ZConvert(pKey, "U")) > 0
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
        For tCube = ..#LINKMANY, ..#LINKONE, ..#VISITS, ..#CATEGORIES, ..#GUARDED, ..#GRID, ..#HIDDEN {
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
        Do ..RemoveListingGroups()
        Do ..RemoveQualityMeasures()
        Do $System.OBJ.DeletePackage(..#PACKAGE, "-d")
        Kill ^OBJ.DSTIME(..#VISITCLASS), ^OBJ.DSTIME(..#CATEGORYCLASS)
        Do ..ForgetBuilds()
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

/// <p>The journal's current position as <code>file|offset</code>, after the journal buffer is flushed, for <method>JournalWrites</method> to scan from
/// (Story 24.11).</p>
ClassMethod JournalMark() As %String
{
    Do ##class(%SYS.Journal.System).Sync()
    Quit ##class(%SYS.Journal.System).GetCurrentFileName() _ "|" _ ##class(%SYS.Journal.System).GetCurrentFileOffset()
}

/// <p>The global writes the calling process made since <var>pMark</var> (a <method>JournalMark</method> answer), one entry of <var>pWrites</var> for each
/// set or kill record of this process (every record type whose name holds <code>SET</code> or <code>KILL</code>, the bit, vector, remote and mirror forms included), as <code>type global node</code>. Answers their count, or -1 when the journal rolled to another file in between,
/// which the scan cannot span. Writes to a database that is not journaled are not seen.</p>
ClassMethod JournalWrites(pMark As %String, Output pWrites) As %Integer
{
    Kill pWrites
    Do ##class(%SYS.Journal.System).Sync()
    Set tName = $Piece(pMark, "|", 1)
    Set tFrom = +$Piece(pMark, "|", 2)
    If ##class(%SYS.Journal.System).GetCurrentFileName() '= tName Quit -1
    Set tFile = ##class(%SYS.Journal.File).%OpenId(tName)
    If '$IsObject(tFile) Quit -1
    Set tCount = 0
    Set tRecord = tFile.LastRecord
    While $IsObject(tRecord) && (tRecord.Address >= tFrom) {
        If (tRecord.ProcessID = $Job) && ((tRecord.TypeName [ "SET") || (tRecord.TypeName [ "KILL")) {
            Set tCount = tCount + 1
            Set pWrites(tCount) = tRecord.TypeName _ " " _ tRecord.GlobalReference
        }
        Set tRecord = tRecord.Prev
    }
    Quit tCount
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
        For tCube = ..#VISITS, ..#CATEGORIES, ..#GUARDED, ..#GRID, ..#LINKONE, ..#LINKMANY, ..#HIDDEN {
            If ##class(%DeepSee.Utils).%CubeExists(tCube) Set tLeft = tLeft _ ",cube " _ tCube
        }
        If ..BuildsLeft() Set tLeft = tLeft _ ",build residue"
        For tGroup = ..#LISTGROUP, ..#LISTGROUPSAVED, ..#LISTGROUPHIDDEN, ..#LISTGROUPOFF, ..#LISTGROUPBROKEN {
            If $Data(^DeepSee.ListingGroups("groups", $ZConvert(tGroup, "U"))) Set tLeft = tLeft _ ",listing group " _ tGroup
        }
        Set tName = $Order(^DeepSee.ListingGroups("groups", $ZConvert(..#LISTGROUPWRITE, "U")), -1)
        Set tName = $Order(^DeepSee.ListingGroups("groups", tName))
        If $Extract(tName, 1, $Length(..#LISTGROUPWRITE)) = $ZConvert(..#LISTGROUPWRITE, "U") Set tLeft = tLeft _ ",listing group " _ tName
        ; The registry's class nodes and the cubes' listing nodes the listing group tests' compiles register, which RemoveListingGroups kills.
        For tClass = ..#LISTGROUPCLASS, ..#LISTGROUPSAVEDCLASS, ..#LISTGROUPHIDDENCLASS, ..#LISTGROUPOFFCLASS, ..#LISTGROUPBROKENCLASS, ..#LISTGROUPTWINCLASS, ..#LISTGROUPTWINLATECLASS {
            If $Data(^DeepSee.ListingGroups("classes", tClass)) Set tLeft = tLeft _ ",listing group class node " _ tClass
        }
        For tPrefix = ..#LISTGROUPWRITECLASS, ..#LISTGROUPOWNCLASS {
            Set tName = $Order(^DeepSee.ListingGroups("classes", tPrefix), -1)
            Set tName = $Order(^DeepSee.ListingGroups("classes", tName))
            If $Extract(tName, 1, $Length(tPrefix)) = tPrefix Set tLeft = tLeft _ ",listing group class node " _ tName
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %Dictionary.ClassDefinition WHERE Name %STARTSWITH ?", tPrefix)
            If tRS.%Next() && (+tRS.%GetData(1) > 0) Set tLeft = tLeft _ ",listing group classes " _ tPrefix
        }
        For tCube = ..#VISITS, ..#CATEGORIES, ..#LISTGROUPNOCUBE {
            Set tListing = $Order(^DeepSee.ListingGroups("cubes", $ZConvert(tCube, "U"), "listing", ..#LISTINGWRITE), -1)
            Set tListing = $Order(^DeepSee.ListingGroups("cubes", $ZConvert(tCube, "U"), "listing", tListing))
            If $Extract(tListing, 1, $Length(..#LISTINGWRITE)) = ..#LISTINGWRITE Set tLeft = tLeft _ ",cube listing node " _ tCube _ "/" _ tListing
        }
        ; The quality measures' registry nodes, which a class delete removes only for the class the name is registered to.
        For tName = ..#QMCOMPILED, ..#QMREFUSED, ..#QMLINKED, ..#QMOFF, ..#QMNOAREA, ..#QMMASTER, ..#QMDANGLING {
            If $Data(^DeepSee.QMsrs("qmsrNames", $ZConvert(tName, "U"))) Set tLeft = tLeft _ ",quality measure " _ tName
            If $Data(^DeepSee.QMsrs("cubes", $ZConvert(..#VISITS, "U"), $ZConvert(tName, "U"))) Set tLeft = tLeft _ ",quality measure cube node " _ tName
            If $Data(^DeepSee.QMsrs("cubes", $ZConvert(..#QMMISSINGAREA, "U"), $ZConvert(tName, "U"))) Set tLeft = tLeft _ ",quality measure missing-area node " _ tName
        }
        For tClass = ..#QMCOMPILEDCLASS, ..#QMREFUSEDCLASS, ..#QMLINKEDCLASS, ..#QMOFFCLASS, ..#QMTWINCLASS, ..#QMTWINLATECLASS, ..#QMNOAREACLASS, ..#QMMASTERCLASS, ..#QMDANGLINGCLASS {
            If $Data(^DeepSee.QMsrs("qmsrClasses", tClass)) Set tLeft = tLeft _ ",quality measure class node " _ tClass
        }
        If ..KillQualityMeasureWriteNodes(0) Set tLeft = tLeft _ ",quality measure write nodes"
        For tPrefix = ..#QMWRITE _ ".", ..#QMWRITEOWNCLASS, ..#QMPART _ ".", ..#QMPARTOWNCLASS {
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %Dictionary.ClassDefinition WHERE UPPER(Name) %STARTSWITH ?", $ZConvert(tPrefix, "U"))
            If tRS.%Next() && (+tRS.%GetData(1) > 0) Set tLeft = tLeft _ ",quality measure classes " _ tPrefix
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
