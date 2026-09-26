/// <p>GENERATED FILE -- DO NOT EDIT. Every non-<code>GET</code> route of the instance's
/// administration API, as <code>{endpoint, type, verb, url}</code>: the endpoint package-relative
/// and the request type as <class>OcuPilot.Port.AdminPort</class>'s <method>Invoke</method> names
/// them, the HTTP verb, and the path after <code>/api/admin/v2</code> (AD-3, AD-27, AD-59). A copy-out
/// draft's <code>rest</code> step is addressed from this table and nothing derives it at
/// runtime.</p>
/// <p>Regenerate: <method>Source</method> answers this class's text from
/// <method>OcuPilot.Port.AdminPort.DeriveRoutes</method>; write it over this file.
/// <class>OcuPilot.Test.DraftRegistry</class> fails when the table and a fresh derivation
/// disagree.</p>
Class OcuPilot.Port.AdminRoutes Extends %RegisteredObject
{

/// <p>Whether the table names a route for <var>pEndpoint</var>'s request type <var>pType</var>, with
/// its verb in <var>pVerb</var> and its path in <var>pUrl</var>. Where two routes carry one pair, the
/// first in the table's order answers.</p>
ClassMethod Route(pEndpoint As %String, pType As %String, Output pVerb As %String, Output pUrl As %String) As %Boolean
{
    Set pVerb = ""
    Set pUrl = ""
    Set tSC = ..Rows(.tRows)
    If $$$ISERR(tSC) Quit 0
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (tRow.%Get("endpoint") '= pEndpoint) || (tRow.%Get("type") '= pType) Continue
        Set pVerb = tRow.%Get("verb")
        Set pUrl = tRow.%Get("url")
        Quit
    }
    Quit (pVerb '= "")
}

/// <p>The checked-in table, as <code>[{endpoint, type, verb, url}]</code> in <var>pRows</var>.</p>
ClassMethod Rows(Output pRows As %DynamicArray) As %Status
{
    Set pRows = []
    Set tSC = $$$OK
    Try {
        Set tXData = ##class(%Dictionary.CompiledXData).%OpenId($ClassName() _ "||Routes")
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the route table is missing from " _ $ClassName())
            Quit
        }
        Do tXData.Data.Rewind()
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
        If '$IsObject(tParsed) || 'tParsed.%IsA("%Library.DynamicArray") {
            Set tSC = $$$ERROR($$$GeneralError, "the route table in " _ $ClassName() _ " is not an array")
            Quit
        }
        Set pRows = tParsed
    } Catch ex {
        Set pRows = []
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>This class's source with the table <method>OcuPilot.Port.AdminPort.DeriveRoutes</method>
/// answers now, one route per line, in <var>pText</var>.</p>
ClassMethod Source(Output pText As %String) As %Status
{
    Set pText = ""
    Set tSC = ##class(OcuPilot.Port.AdminPort).DeriveRoutes(.tRoutes)
    If $$$ISERR(tSC) Quit tSC
    Set tLines = ""
    Set tIterator = tRoutes.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tLines = tLines _ $Select(tLines = "": "", 1: "," _ $Char(10)) _ tRow.%ToJSON()
    }
    Set tSC = ##class(%Compiler.UDL.TextServices).GetTextAsString($Namespace, $ClassName(), .tSource)
    If $$$ISERR(tSC) Quit tSC
    Set tMarker = $Char(10) _ "XData Routes "
    Set tHead = $Piece(tSource, tMarker, 1)
    Set pText = tHead _ tMarker _ "[ MimeType = application/json ]" _ $Char(10) _ "{" _ $Char(10) _ "[" _ $Char(10) _ tLines _ $Char(10) _ "]" _ $Char(10) _ "}" _ $Char(10) _ $Char(10) _ "}" _ $Char(10)
    Quit $$$OK
}

XData Routes [ MimeType = application/json ]
{
[
{"endpoint":"AsyncResult","type":"CANCEL","verb":"POST","url":"/async-result/cancel"},
{"endpoint":"AsyncResult","type":"PAUSE","verb":"POST","url":"/async-result/pause"},
{"endpoint":"AsyncResult","type":"RESUME","verb":"POST","url":"/async-result/resume"},
{"endpoint":"Database.Actions","type":"COMPACT","verb":"POST","url":"/database-dir/compact"},
{"endpoint":"Database.Actions","type":"DEFRAGMENT","verb":"POST","url":"/database-dir/defragment"},
{"endpoint":"Database.Actions","type":"DISMOUNT","verb":"POST","url":"/database-dir/dismount"},
{"endpoint":"Database.Actions","type":"EXPANDVOL","verb":"POST","url":"/database-dir/expand-volume"},
{"endpoint":"Database.Actions","type":"INTEGRITYCHECK","verb":"POST","url":"/database-dir/integrity-check"},
{"endpoint":"Database.Actions","type":"MODIFYSIZE","verb":"POST","url":"/database-dir/modify-size"},
{"endpoint":"Database.Actions","type":"MOUNT","verb":"POST","url":"/database-dir/mount"},
{"endpoint":"Database.Actions","type":"TRUNCATE","verb":"POST","url":"/database-dir/truncate"},
{"endpoint":"Database.ConfigCRUD","type":"DELETE","verb":"DELETE","url":"/database"},
{"endpoint":"Database.ConfigCRUD","type":"PUT","verb":"PUT","url":"/database"},
{"endpoint":"Database.SysCRUD","type":"DELETE","verb":"DELETE","url":"/database-dir"},
{"endpoint":"Database.SysCRUD","type":"INFO","verb":"POST","url":"/database-dir/info"},
{"endpoint":"Database.SysCRUD","type":"POST","verb":"POST","url":"/database-dir"},
{"endpoint":"Database.SysCRUD","type":"PUT","verb":"PUT","url":"/database-dir"},
{"endpoint":"Device.Settings","type":"PUT","verb":"PUT","url":"/device/settings"},
{"endpoint":"Device.Standard","type":"DELETE","verb":"DELETE","url":"/device"},
{"endpoint":"Device.Standard","type":"PUT","verb":"PUT","url":"/device"},
{"endpoint":"Device.SubType","type":"DELETE","verb":"DELETE","url":"/device/subtype"},
{"endpoint":"Device.SubType","type":"PUT","verb":"PUT","url":"/device/subtype"},
{"endpoint":"DocDB","type":"DELETE","verb":"DELETE","url":"/doc-db"},
{"endpoint":"DocDB","type":"PUT","verb":"PUT","url":"/doc-db"},
{"endpoint":"ECP.AppServerSSLConnection","type":"AUTHORIZE","verb":"POST","url":"/ecp/application-server-ssl-connection/authorize"},
{"endpoint":"ECP.AppServerSSLConnection","type":"DELETE","verb":"DELETE","url":"/ecp/application-server-ssl-connection"},
{"endpoint":"ECP.AppServerSSLConnection","type":"REJECT","verb":"POST","url":"/ecp/application-server-ssl-connection/reject"},
{"endpoint":"ECP.DataServer","type":"DELETE","verb":"DELETE","url":"/ecp/data-server"},
{"endpoint":"ECP.DataServer","type":"PUT","verb":"PUT","url":"/ecp/data-server"},
{"endpoint":"ECP.DataServer","type":"SERVERACTION","verb":"POST","url":"/ecp/data-server/action"},
{"endpoint":"ECP.Settings","type":"PUT","verb":"PUT","url":"/ecp/settings"},
{"endpoint":"FSAccess.Path","type":"DELETE","verb":"DELETE","url":"/fs-access-purpose/path"},
{"endpoint":"FSAccess.Path","type":"PUT","verb":"PUT","url":"/fs-access-purpose/path"},
{"endpoint":"FSAccess.Purpose","type":"DELETE","verb":"DELETE","url":"/fs-access-purpose"},
{"endpoint":"FSAccess.Purpose","type":"PUT","verb":"PUT","url":"/fs-access-purpose"},
{"endpoint":"Journal.File","type":"INTEGRITYCHECK","verb":"POST","url":"/journal/file/integrity-check"},
{"endpoint":"Journal.Record","type":"LIST","verb":"POST","url":"/journal/file/records"},
{"endpoint":"Journal.Settings","type":"PUT","verb":"PUT","url":"/journal/settings"},
{"endpoint":"Journal.Settings","type":"SWITCHDIR","verb":"POST","url":"/journal/switch-dir"},
{"endpoint":"Journal.Settings","type":"SWITCHFILE","verb":"POST","url":"/journal/switch-file"},
{"endpoint":"LanguageServer","type":"DELETE","verb":"DELETE","url":"/ext-lang-server"},
{"endpoint":"LanguageServer","type":"PUT","verb":"PUT","url":"/ext-lang-server"},
{"endpoint":"LanguageServer","type":"START","verb":"POST","url":"/ext-lang-server/start"},
{"endpoint":"LanguageServer","type":"STOP","verb":"POST","url":"/ext-lang-server/stop"},
{"endpoint":"License.Key","type":"PUT","verb":"PUT","url":"/license/key"},
{"endpoint":"License.Key","type":"VALIDATE","verb":"POST","url":"/license/key/validate"},
{"endpoint":"License.Server","type":"DELETE","verb":"DELETE","url":"/license/server"},
{"endpoint":"License.Server","type":"PUT","verb":"PUT","url":"/license/server"},
{"endpoint":"Lock","type":"DELETE","verb":"DELETE","url":"/lock"},
{"endpoint":"Namespace.GlobalMappings","type":"DELETE","verb":"DELETE","url":"/namespace/global-mapping"},
{"endpoint":"Namespace.GlobalMappings","type":"PUT","verb":"PUT","url":"/namespace/global-mapping"},
{"endpoint":"Namespace.Namespace","type":"DELETE","verb":"DELETE","url":"/namespace"},
{"endpoint":"Namespace.Namespace","type":"INTEROP","verb":"POST","url":"/namespace/enable-interop"},
{"endpoint":"Namespace.Namespace","type":"MAPPINGS","verb":"POST","url":"/namespace/copy-mappings"},
{"endpoint":"Namespace.Namespace","type":"PUT","verb":"PUT","url":"/namespace"},
{"endpoint":"Namespace.PackageMappings","type":"DELETE","verb":"DELETE","url":"/namespace/package-mapping"},
{"endpoint":"Namespace.PackageMappings","type":"PUT","verb":"PUT","url":"/namespace/package-mapping"},
{"endpoint":"Namespace.RoutineMappings","type":"DELETE","verb":"DELETE","url":"/namespace/routine-mapping"},
{"endpoint":"Namespace.RoutineMappings","type":"PUT","verb":"PUT","url":"/namespace/routine-mapping"},
{"endpoint":"Process","type":"BROADCAST","verb":"POST","url":"/process/broadcast"},
{"endpoint":"Process","type":"RESUME","verb":"POST","url":"/process/resume"},
{"endpoint":"Process","type":"SUSPEND","verb":"POST","url":"/process/suspend"},
{"endpoint":"Process","type":"TERMINATE","verb":"POST","url":"/process/terminate"},
{"endpoint":"Security.Audit.Enabled","type":"PUT","verb":"PUT","url":"/security/audit/enabled"},
{"endpoint":"Security.Audit.Event","type":"CLEARCOUNT","verb":"POST","url":"/security/audit/event/clear-count"},
{"endpoint":"Security.Audit.Event","type":"DELETE","verb":"DELETE","url":"/security/audit/event"},
{"endpoint":"Security.Audit.Event","type":"PUT","verb":"PUT","url":"/security/audit/event"},
{"endpoint":"Security.Audit.Record","type":"COPY","verb":"POST","url":"/security/audit/record/copy"},
{"endpoint":"Security.Audit.Record","type":"LIST","verb":"POST","url":"/security/audit/records"},
{"endpoint":"Security.Audit.Record","type":"PURGE","verb":"POST","url":"/security/audit/record/purge"},
{"endpoint":"Security.Encryption.AdminInFile","type":"DELETE","verb":"DELETE","url":"/security/encryption/file/admin"},
{"endpoint":"Security.Encryption.AdminInFile","type":"POST","verb":"POST","url":"/security/encryption/file/admin"},
{"endpoint":"Security.Encryption.File","type":"ACTIVATE","verb":"POST","url":"/security/encryption/file/activate"},
{"endpoint":"Security.Encryption.File","type":"POST","verb":"POST","url":"/security/encryption/file"},
{"endpoint":"Security.Encryption.Key","type":"DEACTIVATE","verb":"POST","url":"/security/encryption/key/deactivate"},
{"endpoint":"Security.Encryption.KeyInFile","type":"DELETE","verb":"DELETE","url":"/security/encryption/file/key"},
{"endpoint":"Security.Encryption.KeyInFile","type":"POST","verb":"POST","url":"/security/encryption/file/key"},
{"endpoint":"Security.Encryption.Settings","type":"PUT","verb":"PUT","url":"/security/encryption/settings"},
{"endpoint":"Security.LDAP","type":"CHANGEPWD","verb":"POST","url":"/security/ldap/configuration/search-password"},
{"endpoint":"Security.LDAP","type":"DELETE","verb":"DELETE","url":"/security/ldap/configuration"},
{"endpoint":"Security.LDAP","type":"PUT","verb":"PUT","url":"/security/ldap/configuration"},
{"endpoint":"Security.LDAP","type":"TEST","verb":"POST","url":"/security/ldap/test"},
{"endpoint":"Security.MFT","type":"DELETE","verb":"DELETE","url":"/security/mft/connection"},
{"endpoint":"Security.MFT","type":"PUT","verb":"PUT","url":"/security/mft/connection"},
{"endpoint":"Security.MFT","type":"REVOKE","verb":"DELETE","url":"/security/mft/connection/token"},
{"endpoint":"Security.OAuth2.Client.ClientConfiguration","type":"CHANGESECRET","verb":"POST","url":"/security/oauth2/client/client-configuration/secrets"},
{"endpoint":"Security.OAuth2.Client.ClientConfiguration","type":"DELETE","verb":"DELETE","url":"/security/oauth2/client/client-configuration"},
{"endpoint":"Security.OAuth2.Client.ClientConfiguration","type":"PUT","verb":"PUT","url":"/security/oauth2/client/client-configuration"},
{"endpoint":"Security.OAuth2.Client.ClientConfiguration","type":"REGISTERCLIENT","verb":"POST","url":"/security/oauth2/client/client-configuration/register-client"},
{"endpoint":"Security.OAuth2.Client.ClientConfiguration","type":"ROTATEKEYS","verb":"POST","url":"/security/oauth2/client/client-configuration/rotate-keys"},
{"endpoint":"Security.OAuth2.Client.ServerDefinition","type":"DELETE","verb":"DELETE","url":"/security/oauth2/client/server-definition"},
{"endpoint":"Security.OAuth2.Client.ServerDefinition","type":"POST","verb":"POST","url":"/security/oauth2/client/server-definition"},
{"endpoint":"Security.OAuth2.Client.ServerDefinition","type":"PUT","verb":"PUT","url":"/security/oauth2/client/server-definition"},
{"endpoint":"Security.OAuth2.Client.ServerDefinition","type":"TOKEN","verb":"POST","url":"/security/oauth2/client/server-definition/initial-access-token"},
{"endpoint":"Security.OAuth2.ResourceServer","type":"CHANGESECRET","verb":"POST","url":"/security/oauth2/resource-server/secret"},
{"endpoint":"Security.OAuth2.ResourceServer","type":"DELETE","verb":"DELETE","url":"/security/oauth2/resource-server"},
{"endpoint":"Security.OAuth2.ResourceServer","type":"PUT","verb":"PUT","url":"/security/oauth2/resource-server"},
{"endpoint":"Security.OAuth2.ResourceServerMapping","type":"DELETE","verb":"DELETE","url":"/security/oauth2/resource-server/mapping"},
{"endpoint":"Security.OAuth2.ResourceServerMapping","type":"PUT","verb":"PUT","url":"/security/oauth2/resource-server/mapping"},
{"endpoint":"Security.OAuth2.Server","type":"CHANGEPWD","verb":"POST","url":"/security/oauth2/server/password"},
{"endpoint":"Security.OAuth2.Server","type":"DELETE","verb":"DELETE","url":"/security/oauth2/server"},
{"endpoint":"Security.OAuth2.Server","type":"PUT","verb":"PUT","url":"/security/oauth2/server"},
{"endpoint":"Security.OAuth2.Server","type":"REVOKE","verb":"POST","url":"/security/oauth2/server/revoke"},
{"endpoint":"Security.OAuth2.ServerClients","type":"DELETE","verb":"DELETE","url":"/security/oauth2/server/client"},
{"endpoint":"Security.OAuth2.ServerClients","type":"POST","verb":"POST","url":"/security/oauth2/server/client"},
{"endpoint":"Security.OAuth2.ServerClients","type":"PUT","verb":"PUT","url":"/security/oauth2/server/client"},
{"endpoint":"Security.OAuth2.ServerClients","type":"SECRET","verb":"POST","url":"/security/oauth2/server/client/secret"},
{"endpoint":"Security.PrivilegedRoutine","type":"DELETE","verb":"DELETE","url":"/security/privileged-routine"},
{"endpoint":"Security.PrivilegedRoutine","type":"PUT","verb":"PUT","url":"/security/privileged-routine"},
{"endpoint":"Security.Resource","type":"DELETE","verb":"DELETE","url":"/security/resource"},
{"endpoint":"Security.Resource","type":"PUT","verb":"PUT","url":"/security/resource"},
{"endpoint":"Security.Role","type":"DELETE","verb":"DELETE","url":"/security/role"},
{"endpoint":"Security.Role","type":"PUT","verb":"PUT","url":"/security/role"},
{"endpoint":"Security.SQLPrivilege.Admin","type":"GRANT","verb":"POST","url":"/security/sql-admin-privilege/grant"},
{"endpoint":"Security.SQLPrivilege.Admin","type":"HEAD","verb":"HEAD","url":"/security/sql-admin-privilege"},
{"endpoint":"Security.SQLPrivilege.Admin","type":"REVOKE","verb":"POST","url":"/security/sql-admin-privilege/revoke"},
{"endpoint":"Security.SQLPrivilege.Column","type":"GRANT","verb":"POST","url":"/security/sql-column-privilege/grant"},
{"endpoint":"Security.SQLPrivilege.Column","type":"HEAD","verb":"HEAD","url":"/security/sql-column-privilege"},
{"endpoint":"Security.SQLPrivilege.Column","type":"REVOKE","verb":"POST","url":"/security/sql-column-privilege/revoke"},
{"endpoint":"Security.SQLPrivilege.Standard","type":"GRANT","verb":"POST","url":"/security/sql-privilege/grant"},
{"endpoint":"Security.SQLPrivilege.Standard","type":"HEAD","verb":"HEAD","url":"/security/sql-privilege"},
{"endpoint":"Security.SQLPrivilege.Standard","type":"REVOKE","verb":"POST","url":"/security/sql-privilege/revoke"},
{"endpoint":"Security.SSLConfig","type":"DELETE","verb":"DELETE","url":"/security/ssl-configuration"},
{"endpoint":"Security.SSLConfig","type":"PUT","verb":"PUT","url":"/security/ssl-configuration"},
{"endpoint":"Security.SSLConfig","type":"TEST","verb":"POST","url":"/security/ssl-configuration/test"},
{"endpoint":"Security.Service","type":"PUT","verb":"PUT","url":"/security/service"},
{"endpoint":"Security.Superserver","type":"DELETE","verb":"DELETE","url":"/security/superserver"},
{"endpoint":"Security.Superserver","type":"PUT","verb":"PUT","url":"/security/superserver"},
{"endpoint":"Security.User","type":"CHANGEPWD","verb":"POST","url":"/security/user/password"},
{"endpoint":"Security.User","type":"DELETE","verb":"DELETE","url":"/security/user"},
{"endpoint":"Security.User","type":"POST","verb":"POST","url":"/security/user"},
{"endpoint":"Security.User","type":"PUT","verb":"PUT","url":"/security/user"},
{"endpoint":"Security.WebAuth","type":"CHANGESMTPPWD","verb":"POST","url":"/security/web-auth/smtp-password"},
{"endpoint":"Security.WebAuth","type":"PUT","verb":"PUT","url":"/security/web-auth"},
{"endpoint":"Security.X509Credential","type":"DELETE","verb":"DELETE","url":"/security/x509-credential"},
{"endpoint":"Security.X509Credential","type":"POST","verb":"POST","url":"/security/x509-credential"},
{"endpoint":"Security.X509Credential","type":"PUT","verb":"PUT","url":"/security/x509-credential"},
{"endpoint":"Task.CRUD","type":"DELETE","verb":"DELETE","url":"/task"},
{"endpoint":"Task.CRUD","type":"POST","verb":"POST","url":"/task"},
{"endpoint":"Task.CRUD","type":"PUT","verb":"PUT","url":"/task"},
{"endpoint":"Task.CRUD","type":"RESUME","verb":"POST","url":"/task/resume"},
{"endpoint":"Task.CRUD","type":"RUN","verb":"POST","url":"/task/run"},
{"endpoint":"Task.CRUD","type":"SUSPEND","verb":"POST","url":"/task/suspend"},
{"endpoint":"Task.Manager","type":"RESUME","verb":"POST","url":"/task/manager/resume"},
{"endpoint":"Task.Manager","type":"RUN","verb":"POST","url":"/task/manager/run"},
{"endpoint":"Task.Manager","type":"SUSPEND","verb":"POST","url":"/task/manager/suspend"},
{"endpoint":"WQMCategory","type":"DELETE","verb":"DELETE","url":"/wqm-category"},
{"endpoint":"WQMCategory","type":"PUT","verb":"PUT","url":"/wqm-category"},
{"endpoint":"Wallet.Collection","type":"DELETE","verb":"DELETE","url":"/wallet/collection"},
{"endpoint":"Wallet.Collection","type":"PUT","verb":"PUT","url":"/wallet/collection"},
{"endpoint":"Wallet.Secret","type":"DELETE","verb":"DELETE","url":"/wallet/secret"},
{"endpoint":"Wallet.Secret","type":"PUT","verb":"PUT","url":"/wallet/secret"},
{"endpoint":"WebApp.App","type":"DELETE","verb":"DELETE","url":"/web-app"},
{"endpoint":"WebApp.App","type":"PUT","verb":"PUT","url":"/web-app"},
{"endpoint":"WebApp.PctClassAccess","type":"DELETE","verb":"DELETE","url":"/web-app/pct-access"},
{"endpoint":"WebApp.PctClassAccess","type":"PUT","verb":"PUT","url":"/web-app/pct-access"},
{"endpoint":"WebSession","type":"DELETE","verb":"DELETE","url":"/web-session"}
]
}

}
