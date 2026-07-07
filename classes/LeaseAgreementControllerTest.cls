@IsTest
private class LeaseAgreementControllerTest {
    private static Lease_Agreement__c buildLease(String tenantEmail) {
        Property__c property = TestDataFactory.createProperties(1, null, true)[0];
        Map<String, Object> tenantFields = new Map<String, Object>{ 'Email__c' => tenantEmail };
        Tenant__c tenant = TestDataFactory.createTenants(1, tenantFields, true)[0];
        return TestDataFactory.createLeases(
            1,
            new Map<String, Object>{
                'Property__c' => property.Id,
                'Tenant__c' => tenant.Id,
                'End_Date__c' => Date.today().addDays(30)
            },
            true
        )[0];
    }

    @IsTest
    static void getLeaseDataReturnsExpectedValues() {
        Lease_Agreement__c lease = buildLease('renter@example.com');

        Test.startTest();
        LeaseAgreementController.LeaseData data = LeaseAgreementController.getLeaseData(lease.Id);
        Test.stopTest();

        Assert.isNotNull(data, 'Wrapper should be returned.');
        Lease_Agreement__c insertedLease = [SELECT Name FROM Lease_Agreement__c WHERE Id = :lease.Id];
        Assert.areEqual(insertedLease.Name, data.leaseName, 'Lease name should match.');
        Assert.areEqual('renter@example.com', data.tenantEmail, 'Tenant email should match.');
        Assert.isNotNull(data.propertyName, 'Property name should be populated.');
        Assert.isTrue(data.propertyAddress.contains('Bengaluru'), 'Address should contain the city.');
        Assert.areEqual(50000, data.agreedMonthlyRent, 'Agreed monthly rent should match the default.');
    }

    @IsTest
    static void getLeaseDataThrowsWhenNotFound() {
        Boolean threw = false;
        Property__c property = TestDataFactory.createProperties(1, null, true)[0];
        Tenant__c tenant = TestDataFactory.createTenants(1, null, true)[0];
        Lease_Agreement__c lease = TestDataFactory.createLeases(
            1,
            new Map<String, Object>{
                'Property__c' => property.Id,
                'Tenant__c' => tenant.Id,
                'End_Date__c' => Date.today().addDays(30)
            },
            true
        )[0];
        delete lease;

        Test.startTest();
        try {
            LeaseAgreementController.getLeaseData(lease.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        Assert.isTrue(threw, 'Deleted lease lookup should throw AuraHandledException.');
    }

    @IsTest
    static void sendLeaseEmailSucceeds() {
        Lease_Agreement__c lease = buildLease('renter@example.com');
        String pdfBase64 = EncodingUtil.base64Encode(Blob.valueOf('Sample PDF content'));

        Test.startTest();
        String result = LeaseAgreementController.sendLeaseEmail(lease.Id, pdfBase64, 'lease.pdf');
        Test.stopTest();

        Assert.isTrue(result.contains('renter@example.com'), 'Result should confirm the recipient.');
    }

    @IsTest
    static void sendLeaseEmailThrowsWhenPdfMissing() {
        Lease_Agreement__c lease = buildLease('renter@example.com');
        Boolean threw = false;

        Test.startTest();
        try {
            LeaseAgreementController.sendLeaseEmail(lease.Id, '', 'lease.pdf');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        Assert.isTrue(threw, 'Blank PDF content should throw AuraHandledException.');
    }

    @IsTest
    static void sendLeaseEmailThrowsWhenTenantEmailMissing() {
        Lease_Agreement__c lease = buildLease(null);
        String pdfBase64 = EncodingUtil.base64Encode(Blob.valueOf('Sample PDF content'));
        Boolean threw = false;

        Test.startTest();
        try {
            LeaseAgreementController.sendLeaseEmail(lease.Id, pdfBase64, 'lease.pdf');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        Assert.isTrue(threw, 'Missing tenant email should throw AuraHandledException.');
    }
}