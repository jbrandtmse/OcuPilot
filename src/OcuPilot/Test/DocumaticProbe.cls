/// <p>Story 19.9's probe class, created in a namespace by the class reference's browser spec and
/// removed by <method>Remove</method>, which names only package <parameter>PACKAGE</parameter>.</p>
/// <p><parameter>CLASS</parameter> extends <class>%Persistent</class>, so its class reference links
/// to <class>%Library.Persistent</class>. Its description opens with a script element that sets
/// <code>window.ocuprobe199</code>, so a frame that runs the vendor page's scripts can be told from
/// one that does not, then an image at <parameter>IMAGE</parameter>, which the instance does not
/// hold, so a spec that holds its request keeps the page's load pending, then
/// <parameter>TEXT</parameter>.</p>
Class OcuPilot.Test.DocumaticProbe Extends %RegisteredObject
{

/// <p>The package the probe class is created in.</p>
Parameter PACKAGE = "OcuProbe199";

/// <p>The probe class's name.</p>
Parameter CLASS = "OcuProbe199.Doc";

/// <p>The text the probe class's description carries after its script element and its image.</p>
Parameter TEXT = "OcuProbe199 class reference probe.";

/// <p>The address of the image the probe class's description names.</p>
Parameter IMAGE = "/csp/documatic/ocuprobe199.png";

/// <p>Create and compile <parameter>CLASS</parameter> in <var>pNamespace</var>.</p>
ClassMethod Make(pNamespace As %String) As %Status
{
    Set tCRLF = $Char(13, 10)
    Set tText = "/// <script>window.ocuprobe199=1</script><img src=""" _ ..#IMAGE _ """>" _ ..#TEXT _ tCRLF
    Set tText = tText _ "Class " _ ..#CLASS _ " Extends %Persistent" _ tCRLF _ "{" _ tCRLF _ tCRLF _ "}" _ tCRLF
    Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(pNamespace, ..#CLASS, tText)
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = $System.OBJ.Compile(..#CLASS, "ck-d")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete every class in <parameter>PACKAGE</parameter> from <var>pNamespace</var>; a failing
/// status when any survives or the lookup for survivors fails.</p>
ClassMethod Remove(pNamespace As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do $System.OBJ.DeletePackage(..#PACKAGE, "-d")
        Set tLeft = ""
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE Name %STARTSWITH ?", ..#PACKAGE _ ".")
        If tRS.%SQLCODE < 0 {
            Set $NAMESPACE = tOrigNS
            Set tSC = $$$ERROR($$$GeneralError, "the probe class lookup failed in " _ pNamespace _ ": " _ tRS.%Message)
            Quit
        }
        While tRS.%Next() {
            Set tLeft = tLeft _ " " _ tRS.%GetData(1)
        }
        Set $NAMESPACE = tOrigNS
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "probe classes survive in " _ pNamespace _ ":" _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
