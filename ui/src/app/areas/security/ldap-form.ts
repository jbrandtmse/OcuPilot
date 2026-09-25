import type { ReducedFormDeclaration } from '../../core/reduced-form.store';
import { STRINGS } from '../../core/strings';

/** `LDAPFlags` bit 6: the configuration is enabled (`Security.LDAPConfigs`). */
export const LDAP_ENABLED_BIT = 64;

/**
 * The reduced LDAP configuration form (Story 9.9, FR-45): its description, whether it is enabled,
 * its host names and how users are found, in the classic order, saved through
 * `PUT /ldap/<name>` and ended by the classic-link-card to the LDAP configurations page, which
 * keeps the group, attribute, Kerberos, TLS and search password settings until Story 16.14. It
 * edits and never creates.
 *
 * **LDAP enabled is one bit of `LDAPFlags`** (`LDAP_ENABLED_BIT`): ticking it sets that bit on the
 * value the form opened and keeps every other one, and the Save sends the whole number.
 */
export const LDAP_FORM: ReducedFormDeclaration = {
  descriptor: 'OcuPilot.Screen.Descriptor.LdapConfigForm',
  formPath: '/api/ocupilot/ldap/form',
  savePath: '/api/ocupilot/ldap',
  answerKey: 'ldap',
  entityType: 'ldap-configuration',
  listRoute: 'security/ldap',
  bareSentence: STRINGS.ldapFormBare,
  goneSentence: STRINGS.ldapGone,
  fields: [
    { key: 'Description', kind: 'text', label: STRINGS.tableColumnDescription },
    { key: 'LDAPFlags', kind: 'flag', bit: LDAP_ENABLED_BIT, label: STRINGS.ldapFieldEnabled },
    {
      key: 'LDAPHostNames',
      kind: 'list',
      label: STRINGS.ldapFieldHostNames,
      addLabel: STRINGS.ldapHostField,
      addAction: STRINGS.ldapHostAdd,
      caption: STRINGS.ldapHostCaption,
    },
    { key: 'LDAPSearchUsername', kind: 'text', label: STRINGS.ldapFieldSearchUsername },
    { key: 'LDAPBaseDN', kind: 'text', label: STRINGS.ldapFieldBaseDn },
    { key: 'LDAPUniqueDNIdentifier', kind: 'text', label: STRINGS.ldapFieldUniqueAttribute },
  ],
};
