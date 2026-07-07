public with sharing class PropertyTriggerHandler {
    private static final List<String> ADDRESS_FIELDS = new List<String>{
        'Street__c', 'City__c', 'State__c', 'Postal_Code__c', 'Country__c'
    };

    public static Boolean bypassGeocoding = false;

    public static void afterInsert(List<Property__c> newRecords) {
        if (bypassGeocoding) {
            return;
        }
        Set<Id> propertyIds = new Set<Id>();
        for (Property__c prop : newRecords) {
            propertyIds.add(prop.Id);
        }
        enqueue(propertyIds);
    }

    public static void afterUpdate(List<Property__c> newRecords, Map<Id, Property__c> oldMap) {
        if (bypassGeocoding) {
            return;
        }
        Set<Id> propertyIds = new Set<Id>();
        for (Property__c prop : newRecords) {
            Property__c oldProp = oldMap.get(prop.Id);
            if (addressChanged(prop, oldProp)) {
                propertyIds.add(prop.Id);
            }
        }
        enqueue(propertyIds);
    }

    private static Boolean addressChanged(Property__c newProp, Property__c oldProp) {
        for (String field : ADDRESS_FIELDS) {
            if (newProp.get(field) != oldProp.get(field)) {
                return true;
            }
        }
        return false;
    }

    private static void enqueue(Set<Id> propertyIds) {
        if (propertyIds.isEmpty()) {
            return;
        }
        if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
            return;
        }
        System.enqueueJob(new GeocodingService(propertyIds));
    }
}