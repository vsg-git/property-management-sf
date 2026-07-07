public with sharing class LeaseAgreementTriggerHandler {
    public static void handleAfterInsert(List<Lease_Agreement__c> newLeases) {
        Set<Id> propertyIds = new Set<Id>();
        Set<Id> tenantIds = new Set<Id>();
        for (Lease_Agreement__c lease : newLeases) {
            if (lease.Property__c != null) {
                propertyIds.add(lease.Property__c);
            }
            if (lease.Tenant__c != null) {
                tenantIds.add(lease.Tenant__c);
            }
        }

        Map<Id, Property__c> propertiesById = new Map<Id, Property__c>(
            [SELECT Id, Name FROM Property__c WHERE Id IN :propertyIds]
        );
        Map<Id, Tenant__c> tenantsById = new Map<Id, Tenant__c>(
            [SELECT Id, Name FROM Tenant__c WHERE Id IN :tenantIds]
        );

        List<Task> tasksToInsert = new List<Task>();
        for (Lease_Agreement__c lease : newLeases) {
            String propertyName = propertiesById.containsKey(lease.Property__c)
                ? propertiesById.get(lease.Property__c).Name
                : '';
            String tenantName = tenantsById.containsKey(lease.Tenant__c)
                ? tenantsById.get(lease.Tenant__c).Name
                : '';
            tasksToInsert.add(
                new Task(
                    Subject = 'Generate lease agreement for ' + propertyName + ' / ' + tenantName,
                    WhatId = lease.Id,
                    Status = 'Not Started',
                    Priority = 'Normal',
                    OwnerId = lease.OwnerId
                )
            );
        }

        if (!tasksToInsert.isEmpty()) {
            insert tasksToInsert;
        }
    }
}