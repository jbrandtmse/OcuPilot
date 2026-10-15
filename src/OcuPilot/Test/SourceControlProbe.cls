/// <p>Story 20.10's source-control probe: <method>Enable</method> writes and compiles the hooks class
/// <parameter>HOOKS</parameter> in <parameter>NAMESPACE</parameter> and makes it that namespace's source-control
/// class, and <method>Disable</method> takes all of it away again and fails unless nothing is left. The hooks class
/// records every hook call as <code>$ListBuild(hook, document, $Username, $Job, extra)</code> in the global
/// <parameter>LOG</parameter> of the namespace, whichever process runs it, and answers every document as in source
/// control, editable and checked out by the caller, until <method>Refuse</method> marks one not checked out or
/// <method>Veto</method> makes its <code>OnBeforeSave</code> fail. <method>Action</method> sets the answer
/// <code>UserAction</code> gives.</p>
/// <p><b>Test-only.</b> It is not a <class>%UnitTest.TestCase</class>. It switches the namespace by explicit save and
/// restore and enables source control in <parameter>NAMESPACE</parameter> alone, only when
/// <code>OCUPILOT_ALLOW_NAMESPACE_CONFIG</code> reads <code>1</code> and the namespace has no source-control class of
/// its own; it never replaces one.</p>
Class OcuPilot.Test.SourceControlProbe Extends %RegisteredObject
{

/// <p>The one namespace the probe puts under source control.</p>
Parameter NAMESPACE = "USER";

/// <p>The hooks class <method>Enable</method> writes.</p>
Parameter HOOKS = "OcuProbe2010.SourceControl";

/// <p>The global, in <parameter>NAMESPACE</parameter>, holding the log and the switches.</p>
Parameter LOG = "OcuProbe2010SourceControl";

/// <p>The sentence the hooks class's <code>UserAction</code> asks.</p>
Parameter QUESTION = "OcuPilot probe asks: proceed?";

/// <p>The extended reference to <parameter>LOG</parameter> in <var>pNamespace</var>.</p>
ClassMethod Global(pNamespace As %String) As %String
{
    Quit "^|""" _ pNamespace _ """|" _ ..#LOG
}

/// <p>Put <parameter>NAMESPACE</parameter> under source control with the probe's hooks class, its log empty; a failing
/// status, with nothing changed, when <code>OCUPILOT_ALLOW_NAMESPACE_CONFIG</code> does not read <code>1</code>, when
/// <var>pNamespace</var> is another namespace, or when the namespace names a source-control class other than the
/// probe's.</p>
ClassMethod Enable(pNamespace As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        If $System.Util.GetEnviron("OCUPILOT_ALLOW_NAMESPACE_CONFIG") '= 1 {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.SourceControlProbe puts a namespace under source control and runs on a throwaway container only. OCUPILOT_ALLOW_NAMESPACE_CONFIG does not read 1 here, so nothing was changed.")
            Quit
        }
        If pNamespace '= ..#NAMESPACE {
            Set tSC = $$$ERROR($$$GeneralError, "the probe puts " _ ..#NAMESPACE _ " under source control and no other namespace, not " _ pNamespace)
            Quit
        }
        Set tCurrent = ##class(%Studio.SourceControl.Interface).SourceControlClassGet(pNamespace)
        If tCurrent = ..#HOOKS {
            Set tSC = ##class(%Studio.SourceControl.Interface).SourceControlClassSet($Char(0), pNamespace)
            If $$$ISERR(tSC) Quit
        } ElseIf tCurrent '= "" {
            Set tSC = $$$ERROR($$$GeneralError, pNamespace _ " already names the source-control class " _ tCurrent _ ", which the probe does not replace")
            Quit
        }
        Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(pNamespace, ..#HOOKS, ..HooksText(), $Char(10))
        If $$$ISERR(tSC) Quit
        Set $NAMESPACE = pNamespace
        Set tSC = $System.OBJ.Compile(..#HOOKS, "ck-d")
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        Set tLog = ..Global(pNamespace)
        Kill @tLog
        Set tSC = ##class(%Studio.SourceControl.Interface).SourceControlClassSet(..#HOOKS, pNamespace)
        If $$$ISERR(tSC) Quit
        If ##class(%Studio.SourceControl.Interface).SourceControlClassGet(pNamespace) '= ..#HOOKS {
            Set tSC = $$$ERROR($$$GeneralError, pNamespace _ " does not read the probe's source-control class after it was set")
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Take the probe's source control out of <var>pNamespace</var>: the setting, when it is empty or names the probe's
/// class, then the hooks class and the log. A failing status when anything is left: a setting that reads other than
/// <code>""</code>, the class, or the global.</p>
ClassMethod Disable(pNamespace As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        If pNamespace '= ..#NAMESPACE {
            Set tSC = $$$ERROR($$$GeneralError, "the probe puts " _ ..#NAMESPACE _ " under source control and no other namespace, not " _ pNamespace)
            Quit
        }
        Set tCurrent = ##class(%Studio.SourceControl.Interface).SourceControlClassGet(pNamespace)
        If (tCurrent = "") || (tCurrent = ..#HOOKS) {
            Set tSC = ##class(%Studio.SourceControl.Interface).SourceControlClassSet($Char(0), pNamespace)
        }
        Set $NAMESPACE = pNamespace
        If ##class(%Dictionary.ClassDefinition).%ExistsId(..#HOOKS) Set tSC = $$$ADDSC(tSC, $System.OBJ.Delete(..#HOOKS, "-d"))
        Set tClassLeft = ''##class(%Dictionary.ClassDefinition).%ExistsId(..#HOOKS)
        Set $NAMESPACE = tOrigNS
        Set tLog = ..Global(pNamespace)
        Kill @tLog
        Set tLeft = ""
        Set tSetting = ##class(%Studio.SourceControl.Interface).SourceControlClassGet(pNamespace)
        If tSetting '= "" Set tLeft = tLeft _ " the setting reads " _ tSetting
        If tClassLeft Set tLeft = tLeft _ " the class " _ ..#HOOKS
        If $Data(@tLog) Set tLeft = tLeft _ " the global ^" _ ..#LOG
        If tLeft '= "" Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "source control survives in " _ pNamespace _ ":" _ tLeft))
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Mark document <var>pDocument</var> (a name with its extension) not checked out when <var>pOn</var> is 1, so the
/// source-control edit check refuses a save of it, and checked out by the caller when it is 0.</p>
ClassMethod Refuse(pNamespace As %String, pDocument As %String, pOn As %Boolean)
{
    Set tLog = ..Global(pNamespace)
    If pOn {
        Set @tLog@("refuse", $ZConvert(pDocument, "U")) = 1
    } Else {
        Kill @tLog@("refuse", $ZConvert(pDocument, "U"))
    }
}

/// <p>Make the <code>OnBeforeSave</code> of document <var>pDocument</var> fail with an error of its own when
/// <var>pOn</var> is 1, and succeed when it is 0.</p>
ClassMethod Veto(pNamespace As %String, pDocument As %String, pOn As %Boolean)
{
    Set tLog = ..Global(pNamespace)
    If pOn {
        Set @tLog@("veto", $ZConvert(pDocument, "U")) = 1
    } Else {
        Kill @tLog@("veto", $ZConvert(pDocument, "U"))
    }
}

/// <p>Set the <code>Action</code> the hooks class's <code>UserAction</code> answers: 0 asks nothing, 1 asks
/// <parameter>QUESTION</parameter> in a Yes, No, Cancel dialog.</p>
ClassMethod Action(pNamespace As %String, pAction As %Integer)
{
    Set tLog = ..Global(pNamespace)
    Set @tLog@("action") = +pAction
}

/// <p>Every hook call logged in <var>pNamespace</var>, oldest first, as <code>{hook, name, user, job, extra}</code>.
/// <code>Login</code> is not logged, and <code>extra</code> is <code>Type|Name</code> for a user action and
/// <code>Type|Name|Answer</code> after one.</p>
ClassMethod Entries(pNamespace As %String) As %DynamicArray
{
    Set tEntries = []
    Set tLog = ..Global(pNamespace)
    Set tKey = ""
    For {
        Set tKey = $Order(@tLog@("log", tKey))
        If tKey = "" Quit
        Set tRow = @tLog@("log", tKey)
        Set tEntry = {}
        Do tEntry.%Set("hook", $List(tRow, 1), "string")
        Do tEntry.%Set("name", $List(tRow, 2), "string")
        Do tEntry.%Set("user", $List(tRow, 3), "string")
        Do tEntry.%Set("job", $List(tRow, 4), "string")
        Do tEntry.%Set("extra", $List(tRow, 5), "string")
        Do tEntries.%Push(tEntry)
    }
    Quit tEntries
}

/// <p>Forget the hook calls logged in <var>pNamespace</var>; the switches stay.</p>
ClassMethod Clear(pNamespace As %String)
{
    Set tLog = ..Global(pNamespace)
    Kill @tLog@("log")
}

/// <p>The text of the hooks class <parameter>HOOKS</parameter>: <code>%Studio.SourceControl.Base</code>, with the
/// signatures of <code>%Studio.Extension.Base</code>.</p>
ClassMethod HooksText() As %String
{
    Set tNL = $Char(10)
    Set tText = "Class " _ ..#HOOKS _ " Extends %Studio.SourceControl.Base" _ tNL _ "{" _ tNL _ tNL
    Set tText = tText _ "ClassMethod Note(pHook As %String, pName As %String, pExtra As %String = """")" _ tNL _ "{" _ tNL
    Set tText = tText _ "    Set tN = $Increment(^@LOG@(""log""))" _ tNL
    Set tText = tText _ "    Set ^@LOG@(""log"", tN) = $ListBuild(pHook, pName, $Username, $Job, pExtra)" _ tNL _ "}" _ tNL _ tNL
    Set tText = tText _ "ClassMethod Marked(pKind As %String, pName As %String) As %Boolean" _ tNL _ "{" _ tNL
    Set tText = tText _ "    Quit $Data(^@LOG@(pKind, $ZConvert(pName, ""U""))) # 10" _ tNL _ "}" _ tNL _ tNL
    For tHook = $ListBuild("OnBeforeLoad", "InternalName As %String"), $ListBuild("OnAfterLoad", "InternalName As %String, Object As %RegisteredObject = {$$$NULLOREF}"), $ListBuild("OnAfterSave", "InternalName As %String, Object As %RegisteredObject = {$$$NULLOREF}"), $ListBuild("OnBeforeCompile", "InternalName As %String, ByRef qstruct As %String"), $ListBuild("OnAfterCompile", "InternalName As %String"), $ListBuild("OnBeforeDelete", "InternalName As %String"), $ListBuild("OnAfterDelete", "InternalName As %String") {
        Set tText = tText _ "Method " _ $List(tHook, 1) _ "(" _ $List(tHook, 2) _ ") As %Status" _ tNL _ "{" _ tNL
        Set tText = tText _ "    Do ..Note(""" _ $List(tHook, 1) _ """, InternalName)" _ tNL
        If $List(tHook, 1) = "OnAfterSave" Set tText = tText _ "    W ""OcuProbe2010 saved "", InternalName, !" _ tNL
        Set tText = tText _ "    Quit $$$OK" _ tNL _ "}" _ tNL _ tNL
    }
    Set tText = tText _ "Method OnBeforeSave(InternalName As %String, Location As %String = """", Object As %RegisteredObject = {$$$NULLOREF}) As %Status" _ tNL _ "{" _ tNL
    Set tText = tText _ "    Do ..Note(""OnBeforeSave"", InternalName)" _ tNL
    Set tText = tText _ "    If ..Marked(""veto"", InternalName) Quit $$$ERROR($$$GeneralError, ""OcuProbe2010 vetoed the save"")" _ tNL
    Set tText = tText _ "    If ..Marked(""refuse"", InternalName) Quit $$$ERROR($$$ItemNotCheckedOut, InternalName)" _ tNL
    Set tText = tText _ "    Quit $$$OK" _ tNL _ "}" _ tNL _ tNL
    Set tText = tText _ "Method GetStatus(InternalName As %String, ByRef IsInSourceControl As %Boolean, ByRef Editable As %Boolean, ByRef IsCheckedOut As %Boolean, ByRef UserCheckedOut As %String) As %Status" _ tNL _ "{" _ tNL
    Set tText = tText _ "    Do ..Note(""GetStatus"", InternalName)" _ tNL
    Set tText = tText _ "    Set IsInSourceControl = 1" _ tNL
    Set tText = tText _ "    Set Editable = '..Marked(""refuse"", InternalName)" _ tNL
    Set tText = tText _ "    Set IsCheckedOut = Editable" _ tNL
    Set tText = tText _ "    Set UserCheckedOut = $Select(Editable: $Username, 1: """")" _ tNL
    Set tText = tText _ "    Quit $$$OK" _ tNL _ "}" _ tNL _ tNL
    Set tText = tText _ "Method UserAction(Type As %Integer, Name As %String, InternalName As %String, SelectedText As %String, ByRef Action As %String, ByRef Target As %String, ByRef Msg As %String, ByRef Reload As %Boolean) As %Status" _ tNL _ "{" _ tNL
    Set tText = tText _ "    Do ..Note(""UserAction"", InternalName, Type _ ""|"" _ Name)" _ tNL
    Set tText = tText _ "    Set Action = +$Get(^@LOG@(""action""))" _ tNL
    Set tText = tText _ "    Set Target = """ _ ..#QUESTION _ """" _ tNL
    Set tText = tText _ "    Set Reload = 0" _ tNL
    Set tText = tText _ "    Quit $$$OK" _ tNL _ "}" _ tNL _ tNL
    Set tText = tText _ "Method AfterUserAction(Type As %Integer, Name As %String, InternalName As %String, Answer As %Integer, Msg As %String = """", ByRef Reload As %Boolean) As %Status" _ tNL _ "{" _ tNL
    Set tText = tText _ "    Do ..Note(""AfterUserAction"", InternalName, Type _ ""|"" _ Name _ ""|"" _ Answer)" _ tNL
    Set tText = tText _ "    Set Reload = 0" _ tNL
    Set tText = tText _ "    Quit $$$OK" _ tNL _ "}" _ tNL _ tNL _ "}" _ tNL
    Quit $Replace(tText, "@LOG@", ..#LOG)
}

}
