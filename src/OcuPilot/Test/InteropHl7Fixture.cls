/// <p>The probe HL7 schemas and principals Story 24.18 Batch 1's tests arrange. A probe is a custom schema named <parameter>MARKER</parameter> and a suffix, in <code>USER</code>
/// (<parameter>SOURCE</parameter>) or <code>HSCUSTOM</code>, saved with the sets the classic New HL7 schema dialog makes (a base, a description and the time) and no vendor audit row.
/// A principal is an instance user and role named with the marker (the workflow fixture removes them). <method>DropProbes</method> removes every probe schema and principal from both
/// namespaces by that marker, in any letter case, and answers whether none is left; <method>Foreign</method> counts the custom schemas of a namespace that are not probes;
/// <method>Text</method> and <method>Body</method> read a schema back as the vendor's own export reads it. A standard schema is never written.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests. It runs only on a throwaway instance, which sets the arming variable
/// <class>OcuPilot.Test.InteropWorkflowCase</class> names. It extends the workflow fixture for its child-process principals and its instance-user removal.</p>
Class OcuPilot.Test.InteropHl7Fixture Extends OcuPilot.Test.InteropWorkflowFixture
{

/// <p>What every probe's name begins with, the principals' included, and the marker in upper case the names are matched against.</p>
Parameter MARKER = "OcuProbe2418";

Parameter MARKERUPPER = "OCUPROBE2418";

Parameter CASE = "OcuPilot.Test.InteropHl7Case";

/// <p>Store the probe schema <var>pName</var> in <var>pNamespace</var> with <var>pBase</var> and <var>pDescription</var>, as the classic dialog stores a new one.</p>
ClassMethod ProbeSchema(pName As %String, pNamespace As %String = {..#SOURCE}, pBase As %String = "", pDescription As %String = "") As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If pBase '= "" Set ^EnsHL7.Schema(pName, "base") = pBase
        If pDescription '= "" Set ^EnsHL7.Description(pName) = pDescription
        Set ^EnsHL7.Schema(pName, "time") = $ZTimeStamp
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pNamespace</var> holds the schema <var>pName</var> under exactly that name.</p>
ClassMethod Held(pName As %String, pNamespace As %String = {..#SOURCE}) As %Boolean
{
    Set tHeld = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tHeld = ($Data(^EnsHL7.Schema(pName)) > 0)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tHeld
}

/// <p>The schema <var>pName</var> of <var>pNamespace</var> as <code>base|description|standard</code>, or <code>&lt;absent&gt;</code>.</p>
ClassMethod Text(pName As %String, pNamespace As %String = {..#SOURCE}) As %String
{
    Set tText = "<absent>"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If $Data(^EnsHL7.Schema(pName)) Set tText = $Get(^EnsHL7.Schema(pName, "base")) _ "|" _ $Get(^EnsHL7.Description(pName)) _ "|" _ (+$Get(^EnsHL7.Description(pName, "std")))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tText = "<unreadable>"
    }
    Quit tText
}

/// <p>The vendor's export of the schema <var>pName</var> of <var>pNamespace</var> from its <code>Document</code> element on, which holds no time, or <code>""</code>.</p>
ClassMethod Body(pName As %String, pNamespace As %String = {..#SOURCE}) As %String
{
    Set tText = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStream = ##class(%Stream.GlobalCharacter).%New()
        Kill tItems
        Set tItems(pName _ ".HL7") = ""
        Set tSC = $System.OBJ.ExportToStream(.tItems, .tStream, "-d")
        If $$$ISOK(tSC) {
            Do tStream.Rewind()
            Set tText = $Piece(tStream.Read(3000000), "<Document", 2, *)
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tText = ""
    }
    Quit tText
}

/// <p>The names of the custom schemas <var>pNamespace</var> holds that are not probes, comma-separated; <code>?</code> when unreadable.</p>
ClassMethod ForeignNames(pNamespace As %String) As %String
{
    Set tNames = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tKey = ""
        For {
            Set tKey = $Order(^EnsHL7.Schema(tKey))
            If tKey = "" Quit
            If '+$Get(^EnsHL7.Description(tKey, "std")) && ($Extract($ZConvert(tKey, "U"), 1, $Length(..#MARKERUPPER)) '= ..#MARKERUPPER) Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tKey
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tNames = "?"
    }
    Quit tNames
}

/// <p>How many custom schemas <var>pNamespace</var> holds that are not probes; -1 when unreadable.</p>
ClassMethod Foreign(pNamespace As %String) As %Integer
{
    Set tNames = ..ForeignNames(pNamespace)
    If tNames = "?" Quit -1
    Quit $Select(tNames = "": 0, 1: $Length(tNames, ","))
}

/// <p>How many standard schemas <var>pNamespace</var> holds.</p>
ClassMethod Standards(pNamespace As %String = {..#SOURCE}) As %Integer
{
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tKey = ""
        For {
            Set tKey = $Order(^EnsHL7.Schema(tKey))
            If tKey = "" Quit
            If +$Get(^EnsHL7.Description(tKey, "std")) Set tCount = tCount + 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>Remove every probe schema of both namespaces by the marker, in any letter case, a probe a failed guard marked standard included: no schema the instance provides carries the marker.</p>
ClassMethod DropSchemas()
{
    Set tOrigNS = $NAMESPACE
    For tNamespace = ..#SOURCE, ..#OTHER {
        Try {
            Set $NAMESPACE = tNamespace
            Set tKey = ""
            For {
                Set tKey = $Order(^EnsHL7.Schema(tKey))
                If tKey = "" Quit
                If $Extract($ZConvert(tKey, "U"), 1, $Length(..#MARKERUPPER)) = ..#MARKERUPPER {
                    Kill ^EnsHL7.Schema(tKey), ^EnsHL7.Description(tKey)
                }
            }
            Set $NAMESPACE = tOrigNS
        } Catch {
            Set $NAMESPACE = tOrigNS
        }
    }
}

/// <p>How many probe schemas both namespaces still hold; -1 when unreadable.</p>
ClassMethod SchemasLeft() As %Integer
{
    Set tLeft = 0
    Set tOrigNS = $NAMESPACE
    For tNamespace = ..#SOURCE, ..#OTHER {
        Try {
            Set $NAMESPACE = tNamespace
            Set tKey = ""
            For {
                Set tKey = $Order(^EnsHL7.Schema(tKey))
                If tKey = "" Quit
                If $Extract($ZConvert(tKey, "U"), 1, $Length(..#MARKERUPPER)) = ..#MARKERUPPER Set tLeft = tLeft + 1
            }
            Set $NAMESPACE = tOrigNS
        } Catch {
            Set $NAMESPACE = tOrigNS
            Set tLeft = -1
        }
        If tLeft < 0 Quit
    }
    Quit tLeft
}

/// <p>Remove every probe schema and every probe instance user and role; answer <code>1</code> when none is left.</p>
ClassMethod DropProbes() As %Boolean
{
    Do ..DropSchemas()
    Set tParent = ##super()
    Quit tParent && (..SchemasLeft() = 0)
}

/// <p>Nothing is stamped by these writes, so there is none to keep or restore.</p>
ClassMethod KeepStamps()
{
}

ClassMethod RestoreStamps()
{
}

ClassMethod RestoreCascade()
{
}

}
