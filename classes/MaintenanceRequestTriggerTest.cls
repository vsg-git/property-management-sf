@IsTest
private class MaintenanceRequestTriggerTest {
    @IsTest
    static void fewerOpenRequestsVendorWins() {
        List<Property__c> props = TestDataFactory.createProperties(1, null, true);
        Id propId = props[0].Id;
        List<Vendor__c> vendors = TestDataFactory.createVendors(2, null, true);
        Id busyVendorId = vendors[0].Id;
        Id idleVendorId = vendors[1].Id;

        TestDataFactory.createMaintenanceRequests(3, new Map<String, Object>{
            'Property__c' => propId,
            'Vendor__c' => busyVendorId,
            'Status__c' => 'Open'
        }, true);

        Test.startTest();
        List<Maintenance_Request__c> newReqs = TestDataFactory.createMaintenanceRequests(1, new Map<String, Object>{
            'Property__c' => propId
        }, true);
        Test.stopTest();

        Maintenance_Request__c assigned = [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :newReqs[0].Id];
        Assert.areEqual(idleVendorId, assigned.Vendor__c, 'Least loaded vendor should be assigned');
    }

    @IsTest
    static void bulkSpreadsEvenly() {
        List<Property__c> props = TestDataFactory.createProperties(1, null, true);
        Id propId = props[0].Id;
        List<Vendor__c> vendors = TestDataFactory.createVendors(4, null, true);
        Set<Id> vendorIds = new Set<Id>();
        for (Vendor__c v : vendors) {
            vendorIds.add(v.Id);
        }

        Test.startTest();
        List<Maintenance_Request__c> newReqs = TestDataFactory.createMaintenanceRequests(200, new Map<String, Object>{
            'Property__c' => propId
        }, true);
        Test.stopTest();

        Map<Id, Integer> counts = new Map<Id, Integer>();
        for (Id vId : vendorIds) {
            counts.put(vId, 0);
        }
        for (Maintenance_Request__c req : [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id IN :newReqs]) {
            Assert.isNotNull(req.Vendor__c, 'Every request should be assigned');
            Assert.isTrue(counts.containsKey(req.Vendor__c), 'Assigned vendor should be one of the candidates');
            counts.put(req.Vendor__c, counts.get(req.Vendor__c) + 1);
        }

        Integer minCount = null;
        Integer maxCount = null;
        for (Id vId : counts.keySet()) {
            Integer c = counts.get(vId);
            if (minCount == null || c < minCount) {
                minCount = c;
            }
            if (maxCount == null || c > maxCount) {
                maxCount = c;
            }
        }
        Assert.areEqual(50, maxCount, 'Even distribution across 4 vendors');
        Assert.areEqual(50, minCount, 'Even distribution across 4 vendors');
    }

    @IsTest
    static void noVendorLeavesNull() {
        List<Property__c> props = TestDataFactory.createProperties(1, null, true);
        Id propId = props[0].Id;

        Test.startTest();
        List<Maintenance_Request__c> newReqs = TestDataFactory.createMaintenanceRequests(1, new Map<String, Object>{
            'Property__c' => propId
        }, true);
        Test.stopTest();

        Maintenance_Request__c assigned = [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :newReqs[0].Id];
        Assert.isNull(assigned.Vendor__c, 'With no vendors the request stays unassigned');
    }

    @IsTest
    static void presetVendorLeftUnchanged() {
        List<Property__c> props = TestDataFactory.createProperties(1, null, true);
        Id propId = props[0].Id;
        List<Vendor__c> vendors = TestDataFactory.createVendors(2, null, true);
        Id chosenVendorId = vendors[1].Id;

        Test.startTest();
        List<Maintenance_Request__c> newReqs = TestDataFactory.createMaintenanceRequests(1, new Map<String, Object>{
            'Property__c' => propId,
            'Vendor__c' => chosenVendorId
        }, true);
        Test.stopTest();

        Maintenance_Request__c assigned = [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :newReqs[0].Id];
        Assert.areEqual(chosenVendorId, assigned.Vendor__c, 'Pre-set vendor must be preserved');
    }

    @IsTest
    static void cityMatchedVendorPreferredOverWrongCity() {
        List<Property__c> props = TestDataFactory.createProperties(1, new Map<String, Object>{
            'City__c' => 'Bengaluru'
        }, true);
        Id propId = props[0].Id;

        List<Vendor__c> wrongCity = TestDataFactory.createVendors(1, new Map<String, Object>{
            'City__c' => 'Mumbai'
        }, true);
        List<Vendor__c> matchCity = TestDataFactory.createVendors(1, new Map<String, Object>{
            'City__c' => 'Bengaluru'
        }, true);
        Id wrongCityVendorId = wrongCity[0].Id;
        Id matchCityVendorId = matchCity[0].Id;

        Assert.isTrue(wrongCityVendorId < matchCityVendorId, 'Wrong-city vendor should have the lower Id');

        Test.startTest();
        List<Maintenance_Request__c> newReqs = TestDataFactory.createMaintenanceRequests(1, new Map<String, Object>{
            'Property__c' => propId
        }, true);
        Test.stopTest();

        Maintenance_Request__c assigned = [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :newReqs[0].Id];
        Assert.areEqual(matchCityVendorId, assigned.Vendor__c, 'City-matched vendor must win over a lower-Id wrong-city vendor');
    }

    @IsTest
    static void cityMatchedLeastLoadedWins() {
        List<Property__c> props = TestDataFactory.createProperties(1, new Map<String, Object>{
            'City__c' => 'Pune'
        }, true);
        Id propId = props[0].Id;

        List<Vendor__c> busyMatch = TestDataFactory.createVendors(1, new Map<String, Object>{
            'City__c' => 'Pune'
        }, true);
        List<Vendor__c> idleMatch = TestDataFactory.createVendors(1, new Map<String, Object>{
            'City__c' => 'Pune'
        }, true);
        Id busyMatchId = busyMatch[0].Id;
        Id idleMatchId = idleMatch[0].Id;

        TestDataFactory.createMaintenanceRequests(2, new Map<String, Object>{
            'Property__c' => propId,
            'Vendor__c' => busyMatchId,
            'Status__c' => 'In Progress'
        }, true);

        Test.startTest();
        List<Maintenance_Request__c> newReqs = TestDataFactory.createMaintenanceRequests(1, new Map<String, Object>{
            'Property__c' => propId
        }, true);
        Test.stopTest();

        Maintenance_Request__c assigned = [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :newReqs[0].Id];
        Assert.areEqual(idleMatchId, assigned.Vendor__c, 'Among city-matched vendors the least loaded should win');
    }

    @IsTest
    static void fallbackToLeastLoadedWhenNoCityMatch() {
        List<Property__c> props = TestDataFactory.createProperties(1, new Map<String, Object>{
            'City__c' => 'Chennai'
        }, true);
        Id propId = props[0].Id;

        List<Vendor__c> busy = TestDataFactory.createVendors(1, new Map<String, Object>{
            'City__c' => 'Delhi'
        }, true);
        List<Vendor__c> idle = TestDataFactory.createVendors(1, new Map<String, Object>{
            'City__c' => 'Kolkata'
        }, true);
        Id busyVendorId = busy[0].Id;
        Id idleVendorId = idle[0].Id;

        TestDataFactory.createMaintenanceRequests(2, new Map<String, Object>{
            'Property__c' => propId,
            'Vendor__c' => busyVendorId,
            'Status__c' => 'Open'
        }, true);

        Test.startTest();
        List<Maintenance_Request__c> newReqs = TestDataFactory.createMaintenanceRequests(1, new Map<String, Object>{
            'Property__c' => propId
        }, true);
        Test.stopTest();

        Maintenance_Request__c assigned = [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :newReqs[0].Id];
        Assert.areEqual(idleVendorId, assigned.Vendor__c, 'With no city match, fall back to the least loaded vendor');
    }

    @IsTest
    static void completedAndCancelledDoNotCountAsWorkload() {
        List<Property__c> props = TestDataFactory.createProperties(1, new Map<String, Object>{
            'City__c' => 'Hyderabad'
        }, true);
        Id propId = props[0].Id;

        List<Vendor__c> heavyHistory = TestDataFactory.createVendors(1, new Map<String, Object>{
            'City__c' => 'Delhi'
        }, true);
        List<Vendor__c> oneActive = TestDataFactory.createVendors(1, new Map<String, Object>{
            'City__c' => 'Delhi'
        }, true);
        Id heavyHistoryId = heavyHistory[0].Id;
        Id oneActiveId = oneActive[0].Id;

        TestDataFactory.createMaintenanceRequests(3, new Map<String, Object>{
            'Property__c' => propId,
            'Vendor__c' => heavyHistoryId,
            'Status__c' => 'Completed'
        }, true);
        TestDataFactory.createMaintenanceRequests(1, new Map<String, Object>{
            'Property__c' => propId,
            'Vendor__c' => heavyHistoryId,
            'Status__c' => 'Cancelled'
        }, true);
        TestDataFactory.createMaintenanceRequests(1, new Map<String, Object>{
            'Property__c' => propId,
            'Vendor__c' => oneActiveId,
            'Status__c' => 'Open'
        }, true);

        Test.startTest();
        List<Maintenance_Request__c> newReqs = TestDataFactory.createMaintenanceRequests(1, new Map<String, Object>{
            'Property__c' => propId
        }, true);
        Test.stopTest();

        Maintenance_Request__c assigned = [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :newReqs[0].Id];
        Assert.areEqual(heavyHistoryId, assigned.Vendor__c, 'Completed/Cancelled work should not count; that vendor stays idle');
    }

    @IsTest
    static void bulkSpreadsEvenlyWithinCity() {
        List<Property__c> props = TestDataFactory.createProperties(1, new Map<String, Object>{
            'City__c' => 'Bengaluru'
        }, true);
        Id propId = props[0].Id;

        List<Vendor__c> matched = TestDataFactory.createVendors(4, new Map<String, Object>{
            'City__c' => 'Bengaluru'
        }, true);
        TestDataFactory.createVendors(2, new Map<String, Object>{
            'City__c' => 'Mumbai'
        }, true);
        Set<Id> matchedIds = new Set<Id>();
        for (Vendor__c v : matched) {
            matchedIds.add(v.Id);
        }

        Test.startTest();
        List<Maintenance_Request__c> newReqs = TestDataFactory.createMaintenanceRequests(200, new Map<String, Object>{
            'Property__c' => propId
        }, true);
        Test.stopTest();

        Map<Id, Integer> counts = new Map<Id, Integer>();
        for (Id vId : matchedIds) {
            counts.put(vId, 0);
        }
        for (Maintenance_Request__c req : [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id IN :newReqs]) {
            Assert.isTrue(matchedIds.contains(req.Vendor__c), 'Only city-matched vendors should be assigned');
            counts.put(req.Vendor__c, counts.get(req.Vendor__c) + 1);
        }

        for (Id vId : counts.keySet()) {
            Assert.areEqual(50, counts.get(vId), 'Even distribution across the 4 matched vendors');
        }
    }
}