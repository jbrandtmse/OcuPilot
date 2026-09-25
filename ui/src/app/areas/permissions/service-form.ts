import type { ReducedFormDeclaration } from '../../core/reduced-form.store';
import { STRINGS } from '../../core/strings';

/** The one character that separates an allowed address from its roles, which only the classic portal edits. */
export const ADDRESS_ROLE_SEPARATOR = '|';

/**
 * The reduced service form (Story 9.9, FR-41): whether the service is enabled and the addresses
 * allowed to connect, in the classic order, saved through `PUT /services/<name>` and ended by the
 * classic-link-card to the Services page, which keeps the authentication methods and per-address
 * roles until Story 16.13.
 *
 * **Its add field takes one bare address.** An entry the service already holds keeps its roles as
 * read, and a `|` typed here is refused before anything is sent, so the form never edits a role.
 * On the service OcuPilot is served through, Enabled is drawn unavailable with the published
 * refusal and a change to the addresses carries the published consequence (AD-10).
 */
export const SERVICE_FORM: ReducedFormDeclaration = {
  descriptor: 'OcuPilot.Screen.Descriptor.ServiceForm',
  formPath: '/api/ocupilot/services/form',
  savePath: '/api/ocupilot/services',
  answerKey: 'service',
  entityType: 'service',
  listRoute: 'permissions/services',
  bareSentence: STRINGS.serviceFormBare,
  goneSentence: STRINGS.serviceGone,
  servingReason: STRINGS.serviceRefusalServing,
  servingEffect: STRINGS.serviceEffectServesOcuPilot,
  fields: [
    { key: 'Enabled', kind: 'toggle', label: STRINGS.serviceFieldEnabled, servingProtected: true },
    {
      key: 'ClientSystems',
      kind: 'list',
      label: STRINGS.serviceFieldClientSystems,
      addLabel: STRINGS.serviceAddressField,
      addAction: STRINGS.serviceAddressAdd,
      emptyCaption: STRINGS.serviceAddressAnyCaption,
      refuse: (entry) => (entry.includes(ADDRESS_ROLE_SEPARATOR) ? STRINGS.serviceAddressNoRoles : ''),
      servingConsequence: true,
    },
  ],
};
