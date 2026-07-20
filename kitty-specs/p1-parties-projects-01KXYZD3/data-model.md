# P1 Parties and Projects Data Model

## BillingIdentity

- `id`: P0 EntityId.
- `kind`: Personal or Company.
- `display_name`, `legal_name`.
- `postal_address_id`.
- optional `email`, `phone`.
- zero or more labeled `tax_identifiers`.
- `default_payment_terms_days`: whole number 0-365.
- optional `preferred_invoice_prefix`; P5 owns sequence state.
- optional `default_logo_asset_id`.
- optional `european_remittance_profile_id`.
- `status`: Active or Inactive.
- audit timestamps/revision.

Invariants:

- Legal name and postal address are required before Active.
- Only Active identities may become new defaults or overrides.
- Deactivation is rejected while any active Client/Project would become
  unresolved; the owner must reassign them in the same durable operation.
- Historical invoice effects are outside this mutable entity.

## PostalAddress

- `line_1`, optional `line_2`/`line_3`.
- `locality`, optional `region`, `postal_code`.
- `country_code`: uppercase ISO 3166-1 alpha-2 shape.

Addresses are structured for display but never used to infer Billing Market.

## TaxIdentifier

- `label`: operator-facing jurisdiction/type label.
- `value`: trimmed value.
- `display_order`.

P1 stores and displays these values; it does not validate legal registration or
calculate tax.

## RemittanceProfile

- `id`, `billing_identity_id`.
- `account_holder`, `bank_name`.
- `iban`: uppercase, spaces removed, structural/check-digit validated.
- `bic_swift`: uppercase, spaces removed, structural validation.
- optional `bank_address`.
- optional `payment_instructions` with strict length/control-character rules.
- `currency`: enabled USD or EUR.
- `status`: Active or Inactive.
- audit timestamps/revision.

Complete means every required field is present and valid. Only complete Active
profiles can satisfy European/show-remittance resolution.

## LogoAsset

- `id`, `owner_kind` (BillingIdentity or Project), `owner_id`.
- `media_type`: image/png or application/pdf.
- `byte_length`: 1 through 2 MiB.
- optional raster `width`/`height`; PDF must be a single accepted page.
- `sha256_digest`, application-owned `storage_path`.
- optional sanitized `display_name`.
- `status`: Active or Inactive.
- audit timestamps/revision.

The content digest is immutable. Replacing artwork creates a new asset; it does
not mutate the old digest/path.

## Client

- `id`, `legal_name`, `display_name`.
- `billing_address_id`.
- zero or more `billing_contacts`; exactly one Primary when Ready.
- optional labeled `tax_identifiers`.
- `billing_market`: Domestic, Europe, or Other.
- optional `other_market_remittance_mode`: Show or Hide, required for Other.
- `default_billing_identity_id`.
- `default_currency`: USD or EUR.
- `default_payment_terms_days`: 0-365.
- optional internal `notes`.
- `status`: Draft, Active, or Archived.
- audit timestamps/revision.

Ready/Active invariants:

- An Active default Billing Identity exists.
- At least one valid billing contact exists and exactly one is Primary.
- Address, Billing Market, currency, and payment terms are valid.
- Other market has an explicit remittance mode.
- Europe can resolve a complete remittance profile through its default identity.

## BillingContact

- `id`, `client_id`, `name`, `email`.
- optional `role`, `phone`.
- `is_primary`, `status`, display order.

Email is used as billing contact data only; P1 sends no email.

## Project

- `id`, `client_id`, `name`, optional `description`.
- `status`: Draft, Active, Paused, Completed, or Archived.
- `identity_mode`: ClientDefault or Explicit.
- optional `billing_identity_override_id` required for Explicit.
- `currency`: enabled USD or EUR.
- `payment_terms_days`: inherited client value or explicit override.
- `cadence`: Monthly or Quarterly.
- `schedule_anchor`: P0 LocalDate.
- `next_billing_date`: P0 LocalDate.
- optional `end_date`.
- `logo_mode`: On or Off.
- optional `project_logo_asset_id`.
- `default_service_description`.
- optional `default_amount`: P0 Money matching Project currency.
- audit timestamps/revision.

Active invariants:

- Client is Active and effective identity is Active.
- Dates are ordered and next billing date does not exceed end date.
- Currency is enabled; default amount currency matches.
- Logo On resolves an Active asset.
- European/show-remittance configuration resolves a complete profile.

P1 never changes `next_billing_date` as a result of billing; P6 owns advancement.

## ResolvedInvoiceConfiguration

A computed, non-persisted view with:

- Project/Client IDs and revisions.
- effective Billing Identity and source (ClientDefault or ProjectOverride).
- immutable-value copies needed by consumers: issuer legal/contact/address,
  recipient legal/contact/address, labeled tax identifiers.
- Billing Market and remittance decision; Remittance Block only when allowed.
- currency and payment terms with source provenance.
- cadence/anchor/next date facts.
- logo decision and resolved asset ID/digest/media type/path.
- readiness errors and stable field paths.

This view is current configuration. P5 owns copying it into an immutable Invoice
Snapshot.

## State transitions

- BillingIdentity: Active -> Inactive; Inactive -> Active after validation.
- RemittanceProfile: Active <-> Inactive; content changes create a new revision.
- LogoAsset: Active -> Inactive; no in-place content replacement.
- Client: Draft -> Active -> Archived; Archived may be restored to Draft for
  explicit revalidation.
- Project: Draft -> Active <-> Paused -> Completed -> Archived. Completed does
  not return to Active without an explicit new decision/audit event.

Every successful transition and reassignment commits, checkpoints, and emits the
matching P1 configuration event before the API reports success.
