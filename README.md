# Real Estate Property Management System (Salesforce)

A Salesforce DX application to manage properties, tenants, lease agreements, vendors, and maintenance requests — with address geocoding and maps, PDF lease generation and email, automated expiry reminders, and intelligent maintenance routing. API 67.0.

## Features

- **Properties** — list view (server-driven paging, filters, sortable columns, nearby-distance search), create form that requires an image (saved atomically with the record), map of the geocoded address.
- **Geocoding** — addresses geocoded to a location field via OpenStreetMap Nominatim (Apex Queueable callout).
- **Tenants & Leases** — a tenant can hold multiple leases; creating a lease auto-creates a Task; generate the lease PDF (jsPDF) and email it to the tenant; scheduled flow emails reminders 1 month and 1 day before expiry.
- **Vendors & Maintenance** — new requests auto-assign to the least-loaded vendor (active requests only), preferring a vendor in the property's city.
- **Home hub** — a single component to browse properties, create a property, and open the dashboard.
- **Reporting** — reports and a dashboard for expiring leases, maintenance by status, and occupancy.

## Data model

| Object | Key fields |
|---|---|
| `Property__c` | Name, Street/City/State/Postal_Code/Country, Type, Furnishing_Status, Status, Rent, Description, Location (geo) |
| `Tenant__c` | Name, Phone, Email |
| `Lease_Agreement__c` | Property, Tenant, Terms, Agreed_Monthly_Rent, Start_Date, End_Date |
| `Vendor__c` | Name, Phone, Email, City |
| `Maintenance_Request__c` | Property, Vendor (auto-assigned), Status, Description |

## Project structure

```
objects, classes, triggers, lwc, layouts, flows,
reports, dashboards, flexipages, permissionsets,
remoteSiteSettings, staticresources, tabs, applications```

## Deploy

```bash
# Deploy all metadata
sf project deploy start -x manifest/package.xml -o <org-alias>

# Assign the permission set
sf org assign permset -n Property_Management -o <org-alias>

```

### Post-deploy (one-time UI)
- In **Lightning App Builder**, add the components to pages: `propertyHome` (or `propertyList` / `propertyCreate`) on a Home/App page; `propertyMap` on the Property record page; `leaseAgreementPdf` on the Lease Agreement record page.
- Set the **Dashboard Id** property on `propertyHome`.
- Set **Email Deliverability** to *All email* for outbound lease emails.

## Tests

```bash
sf apex run test --test-level RunLocalTests --code-coverage --result-format human -o <org-alias>
```

## Roadmap

- **Smarter vendor management** — proximity (distance radius) routing, vendor availability/capacity, skill/category matching, and rebalancing on reopen/reassign.
- **Maintenance lifecycle** — SLA/priority tracking, status-change notifications, and vendor rating.
- **Lease management** — richer PDF templates and configurable reminder cadences.
