@IsTest
public class TestDataFactory {
    public static List<Vendor__c> createVendors(Integer count, Map<String, Object> fields, Boolean doInsert) {
        List<Vendor__c> vendors = new List<Vendor__c>();
        for (Integer i = 0; i < count; i++) {
            Vendor__c vendor = new Vendor__c(
                Name = 'Vendor ' + i,
                Phone__c = '900000' + String.valueOf(i).leftPad(4, '0'),
                Email__c = 'vendor' + i + '@example.com'
            );
            if (fields != null) {
                for (String fieldName : fields.keySet()) {
                    vendor.put(fieldName, fields.get(fieldName));
                }
            }
            vendors.add(vendor);
        }
        if (doInsert && !vendors.isEmpty()) {
            insert vendors;
        }
        return vendors;
    }

    public static List<Tenant__c> createTenants(Integer count, Map<String, Object> fields, Boolean doInsert) {
        List<Tenant__c> tenants = new List<Tenant__c>();
        for (Integer i = 0; i < count; i++) {
            Tenant__c tenant = new Tenant__c(
                Name = 'Tenant ' + i,
                Phone__c = '900001' + String.valueOf(i).leftPad(4, '0'),
                Email__c = 'tenant' + i + '@example.com'
            );
            if (fields != null) {
                for (String fieldName : fields.keySet()) {
                    tenant.put(fieldName, fields.get(fieldName));
                }
            }
            tenants.add(tenant);
        }
        if (doInsert && !tenants.isEmpty()) {
            insert tenants;
        }
        return tenants;
    }

    public static List<Property__c> createProperties(Integer count, Map<String, Object> fields, Boolean doInsert) {
        List<Property__c> properties = new List<Property__c>();
        for (Integer i = 0; i < count; i++) {
            Property__c prop = new Property__c(
                Name = 'Property ' + i,
                Street__c = i + ' Main Street',
                City__c = 'Bengaluru',
                State__c = 'Karnataka',
                Postal_Code__c = '560001',
                Country__c = 'India',
                Type__c = Math.mod(i, 2) == 0 ? 'Residential' : 'Commercial',
                Furnishing_Status__c = 'Furnished',
                Status__c = Math.mod(i, 2) == 0 ? 'Available' : 'Occupied',
                Rent__c = 50000 + (i * 5000),
                Description__c = 'Test property ' + i
            );
            if (fields != null) {
                for (String fieldName : fields.keySet()) {
                    prop.put(fieldName, fields.get(fieldName));
                }
            }
            properties.add(prop);
        }
        if (doInsert && !properties.isEmpty()) {
            insert properties;
        }
        return properties;
    }

    public static List<Lease_Agreement__c> createLeases(Integer count, Map<String, Object> fields, Boolean doInsert) {
        List<Lease_Agreement__c> leases = new List<Lease_Agreement__c>();
        for (Integer i = 0; i < count; i++) {
            Lease_Agreement__c lease = new Lease_Agreement__c(
                Terms__c = 'Standard 12-month lease.',
                Agreed_Monthly_Rent__c = 50000,
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addYears(1)
            );
            if (fields != null) {
                for (String fieldName : fields.keySet()) {
                    lease.put(fieldName, fields.get(fieldName));
                }
            }
            leases.add(lease);
        }
        if (doInsert && !leases.isEmpty()) {
            insert leases;
        }
        return leases;
    }

    public static List<Maintenance_Request__c> createMaintenanceRequests(Integer count, Map<String, Object> fields, Boolean doInsert) {
        List<Maintenance_Request__c> requests = new List<Maintenance_Request__c>();
        for (Integer i = 0; i < count; i++) {
            Maintenance_Request__c request = new Maintenance_Request__c(
                Status__c = 'Open',
                Description__c = 'Maintenance issue ' + i
            );
            if (fields != null) {
                for (String fieldName : fields.keySet()) {
                    request.put(fieldName, fields.get(fieldName));
                }
            }
            requests.add(request);
        }
        if (doInsert && !requests.isEmpty()) {
            insert requests;
        }
        return requests;
    }
}