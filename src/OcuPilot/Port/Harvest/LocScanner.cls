/// <p>The line counter's document source: it lists the current namespace's documents and reads one
/// document's lines for <class>OcuPilot.Port.Harvest.LocClassifier</class>. Only classes, routines,
/// generated routines and include files are counted; other documents a broad spec matches are
/// skipped. Generated documents are left out unless the caller asks for them, because they would count
/// their source twice. A harvested handler body's library, inherited by
/// <class>OcuPilot.Port.Harvest.Loc</class>.</p>
Class OcuPilot.Port.Harvest.LocScanner Extends OcuPilot.Kernel.Utils [ Abstract ]
{

/// <p>List the documents in the current namespace whose names match <var>pSpec</var>, restricted to classes,
/// routines, generated routines and include files.</p>
/// <p><var>pSpec</var> is passed to <code>%RoutineMgr:StudioOpenDialog</code> as it stands, so a spec whose
/// exact name precedes an overlapping wildcard part can drop documents; a caller names parts that do
/// not overlap. <var>pDocs</var> is the count, with the full document names, suffix included, at
/// <code>pDocs(1..n)</code>. A failure partway through the list is an error, not a short list.</p>
ClassMethod EnumerateDocs(pSpec As %String, pIncludeGenerated As %Boolean = 0, Output pDocs) As %Status
{
    Set tSC = $$$OK
    Try {
        Kill pDocs
        Set pDocs = 0
        Set tRS = ##class(%ResultSet).%New("%RoutineMgr:StudioOpenDialog")
        Set tSC = tRS.Execute(pSpec, 1, 1, 0, 1, 0, +pIncludeGenerated)
        If $$$ISERR(tSC) Quit
        ; CR 22.0-5: capture Next's status — a mid-stream query error must
        ; propagate, not read as a silent end-of-results undercount
        Set tSCNext = $$$OK
        While tRS.Next(.tSCNext) {
            Set tName = tRS.Get("Name")
            Set tExt = $ZConvert($Piece(tName, ".", *), "L")
            If (tExt '= "cls") && (tExt '= "mac") && (tExt '= "int") && (tExt '= "inc") Continue
            Set pDocs = pDocs + 1
            Set pDocs(pDocs) = tName
        }
        If $$$ISERR(tSCNext) Set tSC = tSCNext
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The per-class facts the classifier needs. <var>pIsTest</var> is 1 when the compiled class extends
/// <class>%UnitTest.TestCase</class>, and 0 for a class that is not compiled. <var>pPyMethods</var>
/// holds the names of the class's embedded-Python methods as <code>pPyMethods(name) = 1</code>, and is
/// empty when the class is not compiled.</p>
ClassMethod BuildClassMetadata(pClassName As %String, Output pIsTest As %Boolean, ByRef pPyMethods) As %Status
{
    Set tSC = $$$OK
    Set pIsTest = 0
    ; CR 22.0-3: reset the accumulator — a caller reusing one ByRef array across
    ; documents must not inherit the previous class's python-method names
    Kill pPyMethods
    Try {
        Try {
            Set pIsTest = +$CLASSMETHOD(pClassName, "%IsA", "%UnitTest.TestCase")
        } Catch exIsA {
            ; uncompiled or nonexistent class — fall back to not-test
            Set pIsTest = 0
        }
        Set tCC = ##class(%Dictionary.CompiledClass).%OpenId(pClassName)
        If $IsObject(tCC) {
            For tI = 1:1:tCC.Methods.Count() {
                Set tMethod = tCC.Methods.GetAt(tI)
                If tMethod.Language = "python" Set pPyMethods(tMethod.Name) = 1
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Read one document's lines, resolve its facts (a class only; a routine is never a test and has no
/// Python methods) and classify every line. <var>pCounts</var> is the classifier's five buckets and
/// total; <var>pIsTest</var> is the document's test flag.</p>
ClassMethod ScanDoc(pDocName As %String, Output pCounts, Output pIsTest As %Boolean) As %Status
{
    Set tSC = $$$OK
    Set pIsTest = 0
    Try {
        Set tSC = ..DocumentLines(pDocName, .tLines)
        If $$$ISERR(tSC) Quit
        Set tExt = $ZConvert($Piece(pDocName, ".", *), "L")
        If tExt = "cls" {
            Set tClassName = $Piece(pDocName, ".", 1, $Length(pDocName, ".") - 1)
            Set tSC = ..BuildClassMetadata(tClassName, .pIsTest, .tPyMethods)
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ..ClassifyDoc(.tLines, pIsTest, .tPyMethods, .pCounts)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
