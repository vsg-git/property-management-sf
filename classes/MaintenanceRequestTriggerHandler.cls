public with sharing class MaintenanceRequestTriggerHandler {
    public static void assignVendors(List<Maintenance_Request__c> newRequests) {
        List<Maintenance_Request__c> needAssignment = new List<Maintenance_Request__c>();
        Set<Id> propertyIds = new Set<Id>();
        for (Maintenance_Request__c req : newRequests) {
            if (req.Vendor__c == null) {
                needAssignment.add(req);
                if (req.Property__c != null) {
                    propertyIds.add(req.Property__c);
                }
            }
        }
        if (needAssignment.isEmpty()) {
            return;
        }

        Map<Id, Integer> vendorWorkload = new Map<Id, Integer>();
        Map<Id, String> vendorCity = new Map<Id, String>();
        for (Vendor__c vendor : [SELECT Id, City__c FROM Vendor__c ORDER BY Id ASC]) {
            vendorWorkload.put(vendor.Id, 0);
            vendorCity.put(vendor.Id, vendor.City__c);
        }
        if (vendorWorkload.isEmpty()) {
            return;
        }

        Map<Id, String> propertyCity = new Map<Id, String>();
        for (Property__c prop : [SELECT Id, City__c FROM Property__c WHERE Id IN :propertyIds]) {
            propertyCity.put(prop.Id, prop.City__c);
        }

        for (AggregateResult ar : [
            SELECT Vendor__c vendorId, COUNT(Id) c
            FROM Maintenance_Request__c
            WHERE Vendor__c != null AND Status__c IN ('Open', 'In Progress')
            GROUP BY Vendor__c
        ]) {
            Id vendorId = (Id) ar.get('vendorId');
            if (vendorWorkload.containsKey(vendorId)) {
                vendorWorkload.put(vendorId, (Integer) ar.get('c'));
            }
        }

        List<Id> vendorIds = new List<Id>(vendorWorkload.keySet());
        vendorIds.sort();

        for (Maintenance_Request__c req : needAssignment) {
            String targetCity = req.Property__c == null ? null : propertyCity.get(req.Property__c);

            Id selectedVendorId = null;
            Integer minCount = null;
            if (targetCity != null) {
                for (Id vendorId : vendorIds) {
                    if (targetCity.equals(vendorCity.get(vendorId))) {
                        Integer currentCount = vendorWorkload.get(vendorId);
                        if (minCount == null || currentCount < minCount) {
                            minCount = currentCount;
                            selectedVendorId = vendorId;
                        }
                    }
                }
            }

            if (selectedVendorId == null) {
                for (Id vendorId : vendorIds) {
                    Integer currentCount = vendorWorkload.get(vendorId);
                    if (minCount == null || currentCount < minCount) {
                        minCount = currentCount;
                        selectedVendorId = vendorId;
                    }
                }
            }

            req.Vendor__c = selectedVendorId;
            vendorWorkload.put(selectedVendorId, vendorWorkload.get(selectedVendorId) + 1);
        }
    }
}