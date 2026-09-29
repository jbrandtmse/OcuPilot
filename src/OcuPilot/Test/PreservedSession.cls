/// <p>Creates and removes, at test time, a page that puts the web session serving it in preserve
/// mode (<code>%session.Preserve</code> 1), so a test can list a real preserve-mode session on a
/// throwaway: such a session keeps its own process, which holds the session's lock.</p>
/// <p>The page is not shipped source. <method>Create</method> defines and compiles
/// <parameter>PAGE</parameter> in the current namespace, and <method>Remove</method> deletes it,
/// so an install carries no such page. A caller that creates it removes it in its own teardown.
/// While it exists it answers an empty 200 at <method>Path</method> to a caller holding
/// <code>%Admin_Operate:USE</code>, and the session it opens expires after
/// <parameter>TIMEOUT</parameter> seconds without a request.</p>
Class OcuPilot.Test.PreservedSession [ Abstract ]
{

/// <p>The page class <method>Create</method> defines.</p>
Parameter PAGE = "OcuPilot.Test.PreservedSessionPage";

/// <p>Seconds a preserve-mode session the page opened lives without a request.</p>
Parameter TIMEOUT As INTEGER = 300;

/// <p>The page's path under the current namespace's default CSP application.</p>
ClassMethod Path() As %String
{
    Quit "/csp/" _ $ZConvert($NAMESPACE, "L") _ "/" _ ..#PAGE _ ".cls"
}

/// <p>Define and compile <parameter>PAGE</parameter>, replacing any copy a failed run left.</p>
ClassMethod Create() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..Remove()
        If $$$ISERR(tSC) Quit
        Set tClass = ##class(%Dictionary.ClassDefinition).%New(..#PAGE)
        Set tClass.Super = "%CSP.Page"
        Set tClass.ProcedureBlock = 1
        Set tClass.Description = "Test page defined by OcuPilot.Test.PreservedSession.Create and deleted by its Remove."
        For tPair = $ListBuild("CONTENTTYPE", "text/plain"), $ListBuild("SECURITYRESOURCE", "%Admin_Operate:USE") {
            Set tParameter = ##class(%Dictionary.ParameterDefinition).%New()
            Set tParameter.Name = $List(tPair, 1)
            Set tParameter.Default = $List(tPair, 2)
            Do tClass.Parameters.Insert(tParameter)
        }
        Set tMethod = ##class(%Dictionary.MethodDefinition).%New()
        Set tMethod.Name = "OnPreHTTP"
        Set tMethod.ClassMethod = 1
        Set tMethod.ServerOnly = 1
        Set tMethod.ReturnType = "%Boolean"
        Do tMethod.Implementation.WriteLine("    Set %session.AppTimeout = " _ ..#TIMEOUT)
        Do tMethod.Implementation.WriteLine("    Set %session.Preserve = 1")
        Do tMethod.Implementation.WriteLine("    Quit 1")
        Do tClass.Methods.Insert(tMethod)
        Set tMethod = ##class(%Dictionary.MethodDefinition).%New()
        Set tMethod.Name = "OnPage"
        Set tMethod.ClassMethod = 1
        Set tMethod.ServerOnly = 1
        Set tMethod.ReturnType = "%Status"
        Do tMethod.Implementation.WriteLine("    Quit 1")
        Do tClass.Methods.Insert(tMethod)
        Set tSC = tClass.%Save()
        If $$$ISERR(tSC) Quit
        Set tSC = $System.OBJ.Compile(..#PAGE, "ck-d")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete <parameter>PAGE</parameter>, compiled and defined; a failing status when either
/// survives. Nothing to delete is success.</p>
ClassMethod Remove() As %Status
{
    Set tSC = $$$OK
    Try {
        If ..Exists() {
            Set tSC = $System.OBJ.Delete(..#PAGE, "-d")
            If $$$ISERR(tSC) Quit
        }
        If ..Exists() Set tSC = $$$ERROR($$$GeneralError, ..#PAGE _ " is still defined")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <parameter>PAGE</parameter> is defined or compiled in the current namespace.</p>
ClassMethod Exists() As %Boolean
{
    Quit ##class(%Dictionary.ClassDefinition).%ExistsId(..#PAGE) || ##class(%Dictionary.CompiledClass).%ExistsId(..#PAGE)
}

}
