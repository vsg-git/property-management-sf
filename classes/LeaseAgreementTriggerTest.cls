@IsTest
private class LeaseAgreementTriggerTest {
    @IsTest
    static void createsTaskForSingleLease() {
        Property__c property = TestDataFactory.createProperties(1, null, true)[0];
        Tenant__c tenant = TestDataFactory.createTenants(1, null, true)[0];

        Test.startTest();
        Lease_Agreement__c lease = TestDataFactory.createLeases(
            1,
            new Map<String, Object>{
                'Property__c' => property.Id,
                'Tenant__c' => tenant.Id,
                'End_Date__c' => Date.today().addDays(30)
            },
            true
        )[0];
        Test.stopTest();

        List<Task> tasks = [
            SELECT Id, Subject, WhatId, Status, Priority, OwnerId
            FROM Task
            WHERE WhatId = :lease.Id
        ];
        Assert.areEqual(1, tasks.size(), 'Exactly one Task should be created for the lease.');
        Task createdTask = tasks[0];
        Assert.areEqual(
            'Generate lease agreement for ' + property.Name + ' / ' + tenant.Name,
            createdTask.Subject,
            'Task subject should reference the property and tenant names.'
        );
        Assert.areEqual('Not Started', createdTask.Status, 'Status should be Not Started.');
        Assert.areEqual('Normal', createdTask.Priority, 'Priority should be Normal.');
        Assert.areEqual(UserInfo.getUserId(), createdTask.OwnerId, 'Task owner should match the lease owner.');
    }

    @IsTest
    static void createsTasksForBulkLeases() {
        Property__c property = TestDataFactory.createProperties(1, null, true)[0];
        Tenant__c tenant = TestDataFactory.createTenants(1, null, true)[0];

        Test.startTest();
        List<Lease_Agreement__c> leases = TestDataFactory.createLeases(
            200,
            new Map<String, Object>{
                'Property__c' => property.Id,
                'Tenant__c' => tenant.Id,
                'End_Date__c' => Date.today().addDays(60)
            },
            true
        );
        Test.stopTest();

        Assert.areEqual(200, leases.size(), 'All 200 leases should be inserted.');
        Integer taskCount = [SELECT COUNT() FROM Task WHERE WhatId IN :leases];
        Assert.areEqual(200, taskCount, 'One Task should be created per lease in bulk.');
    }
}