/// <p>The one place the product reads, saves, compiles and deletes a single source document through the port to the instance's source code API
/// (AD-61, Story 24.11): <code>DevToolPort</code>'s promote reads a document's version here, and the analytics port's listing group writes
/// (Story 24.11) and the quality measures that follow (Story 24.12) save, compile and delete a class here. Every method takes the class that
/// answers the calls, <code>OcuPilot.Port.AtelierPort</code> in production, so each caller keeps its own seam for a fixture that fails a call.</p>
/// <p>Every call is the port's own typed call, so its gate (<code>AtelierPort.WritePairs</code> for a save, compile or delete) and its refusals apply
/// unchanged; a caller that needs the gate before it reads asks <code>WritePairs</code> itself. Nothing here logs a text or sends one to a
/// model.</p>
Class OcuPilot.Kernel.SourceDocument Extends %RegisteredObject
{

/// <p>The lower-case extension of the document <var>pName</var>.</p>
ClassMethod Extension(pName As %String) As %String
{
    Quit $ZConvert($Piece(pName, ".", $Length(pName, ".")), "L")
}

/// <p>The version a save of the document <var>pName</var> in <var>pNamespace</var> is made against: the <code>modified</code> the source code
/// API's document read answers. A class is read through the class endpoint and any other document through the routine endpoint.</p>
ClassMethod Version(pPortClass As %String, pNamespace As %String, pName As %String, Output pVersion As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ..Document(pPortClass, pNamespace, pName, 1, .tDocument, .pHttpStatus, .pFault)
    Set pVersion = $Select($IsObject($Get(tDocument)): tDocument.%Get("modified"), 1: "")
    Quit tSC
}

/// <p>The text of the class <var>pName</var> in <var>pNamespace</var> and its version, in the form the source code API keeps it: the document's lines
/// joined by a line feed, a final empty line leaving the text ending in one. A class the namespace does not hold is the port's 404.</p>
ClassMethod Read(pPortClass As %String, pNamespace As %String, pName As %String, Output pText As %String, Output pVersion As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pText = ""
    Set pVersion = ""
    Set tSC = ..Document(pPortClass, pNamespace, pName, 0, .tDocument, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(tDocument) || (tDocument.%GetTypeOf("content") '= "array") Quit $$$ERROR($$$GeneralError, "the document read answered no lines")
    Set pVersion = tDocument.%Get("modified")
    Set tIterator = tDocument.%Get("content").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set pText = pText _ $Select(tIndex > 0: $Char(10), 1: "") _ tLine
    }
    Quit $$$OK
}

/// <p>The source code API's document read of <var>pName</var>: <var>pDocument</var> is its <code>{name, form, available, content, modified, ...}</code>.
/// <var>pOneRow</var> bounds the structure rows the read also answers.</p>
ClassMethod Document(pPortClass As %String, pNamespace As %String, pName As %String, pOneRow As %Boolean, Output pDocument As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pDocument = ""
    Kill tQuery
    Set tQuery(##class(OcuPilot.Port.AtelierPort).#NAMESPACEKEY) = pNamespace
    Set tQuery(##class(OcuPilot.Port.AtelierPort).#NAMEKEY) = pName
    Set tQuery(##class(OcuPilot.Port.AtelierPort).#FORMKEY) = "udl"
    If pOneRow Set tQuery(##class(OcuPilot.Port.AtelierPort).#MAXROWSKEY) = 1
    Set tEndpoint = $Select(..Extension(pName) = "cls": ##class(OcuPilot.Port.AtelierPort).#ENDPOINTCLASS, 1: ##class(OcuPilot.Port.AtelierPort).#ENDPOINTROUTINE)
    Quit $ClassMethod(pPortClass, "Invoke", tEndpoint, ##class(OcuPilot.Port.AtelierPort).#REQUESTTYPE, .tQuery, "", .tRows, .pHttpStatus, .pFault, .pDocument)
}

/// <p>Save the class text <var>pText</var> as the class <var>pName</var> in <var>pNamespace</var>, without compiling it: against the version
/// <var>pVersion</var> it was read at, or, when <var>pVersion</var> is empty, as a new class (the port refuses a name the namespace already holds).
/// The port refuses a class that changed since <var>pVersion</var> (409) and a text whose header names another class.</p>
ClassMethod Save(pPortClass As %String, pNamespace As %String, pName As %String, pText As %String, pVersion As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Kill tQuery
    Set tQuery(##class(OcuPilot.Port.AtelierPort).#NAMESPACEKEY) = pNamespace
    Set tQuery(##class(OcuPilot.Port.AtelierPort).#NAMESKEY) = pName
    Set tQuery(##class(OcuPilot.Port.AtelierPort).#CONTENTKEY) = pText
    Set tQuery(##class(OcuPilot.Port.AtelierPort).#COMPILEKEY) = 0
    If pVersion '= "" Set tQuery(##class(OcuPilot.Port.AtelierPort).#VERSIONKEY) = pVersion
    Quit $ClassMethod(pPortClass, "Invoke", ##class(OcuPilot.Port.AtelierPort).#ENDPOINTCLASSES, $Select(pVersion = "": ##class(OcuPilot.Port.AtelierPort).#TYPECREATE, 1: ##class(OcuPilot.Port.AtelierPort).#TYPESAVE), .tQuery, "", .tResult, .pHttpStatus, .pFault)
}

/// <p>Compile the class <var>pName</var> in <var>pNamespace</var>, whether or not it is up to date. A compile that reports an error is the compile's own
/// result, not a refusal: <var>pErrors</var> is whether it did, and <var>pLines</var> are the compiler's own lines, for the caller's log and never for
/// an answer (AD-39).</p>
ClassMethod Compile(pPortClass As %String, pNamespace As %String, pName As %String, Output pErrors As %Boolean, Output pLines As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pErrors = 0
    Set pLines = []
    Kill tQuery
    Set tQuery(##class(OcuPilot.Port.AtelierPort).#NAMESPACEKEY) = pNamespace
    Set tQuery(##class(OcuPilot.Port.AtelierPort).#NAMESKEY) = pName
    Set tQuery(##class(OcuPilot.Port.AtelierPort).#KEEPSOURCEKEY) = 1
    Set tQuery(##class(OcuPilot.Port.AtelierPort).#COMPILEDEPENDENTSKEY) = 0
    Set tQuery(##class(OcuPilot.Port.AtelierPort).#SKIPUPTODATEKEY) = 0
    Set tSC = $ClassMethod(pPortClass, "Invoke", ##class(OcuPilot.Port.AtelierPort).#ENDPOINTCLASSES, ##class(OcuPilot.Port.AtelierPort).#TYPECOMPILE, .tQuery, "", .tResult, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set pErrors = '$IsObject(tResult) || ''tResult.%Get("errors")
    If $IsObject(tResult) && (tResult.%GetTypeOf("lines") = "array") Set pLines = tResult.%Get("lines")
    Quit $$$OK
}

/// <p>Delete the class <var>pName</var> from <var>pNamespace</var>, which also removes what its compile registered. <var>pDeleted</var> is whether the
/// port answered the class deleted.</p>
ClassMethod Remove(pPortClass As %String, pNamespace As %String, pName As %String, Output pDeleted As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pDeleted = 0
    Kill tQuery
    Set tQuery(##class(OcuPilot.Port.AtelierPort).#NAMESPACEKEY) = pNamespace
    Set tQuery(##class(OcuPilot.Port.AtelierPort).#NAMESKEY) = pName
    Set tSC = $ClassMethod(pPortClass, "Invoke", ##class(OcuPilot.Port.AtelierPort).#ENDPOINTCLASSES, ##class(OcuPilot.Port.AtelierPort).#TYPEDELETE, .tQuery, "", .tResult, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If $IsObject(tResult) && (tResult.%GetTypeOf("documents") = "array") {
        Set tIterator = tResult.%Get("documents").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tDocument) {
            If tDocument.%Get("deleted") Set pDeleted = 1
        }
    }
    Quit $$$OK
}

}
