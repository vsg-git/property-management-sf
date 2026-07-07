@IsTest
private class PropertyTriggerTest {
    private class GeoMock implements HttpCalloutMock {
        public Integer calloutCount = 0;
        public HttpResponse respond(HttpRequest request) {
            calloutCount++;
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('[{"lat":"12.9716","lon":"77.5946"}]');
            return response;
        }
    }

    @TestSetup
    static void setup() {
        TestDataFactory.createProperties(3, null, true);
    }

    @IsTest
    static void testInsertEnqueuesGeocoding() {
        GeoMock mock = new GeoMock();
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        List<Property__c> props = TestDataFactory.createProperties(3, null, true);
        Test.stopTest();

        Assert.areEqual(3, mock.calloutCount, 'One callout per inserted property');
        List<Property__c> updated = [
            SELECT Location__Latitude__s FROM Property__c WHERE Id IN :props
        ];
        for (Property__c prop : updated) {
            Assert.areEqual(12.9716, prop.Location__Latitude__s, 'Location geocoded on insert');
        }
    }

    @IsTest
    static void testAddressUpdateEnqueuesGeocoding() {
        Property__c prop = [SELECT Id, City__c FROM Property__c LIMIT 1];

        GeoMock updateMock = new GeoMock();
        Test.setMock(HttpCalloutMock.class, updateMock);
        Test.startTest();
        prop.City__c = 'Mumbai';
        update prop;
        Test.stopTest();

        Assert.areEqual(1, updateMock.calloutCount, 'Address change re-triggers geocoding');
    }

    @IsTest
    static void testNonAddressUpdateSkipsGeocoding() {
        Property__c prop = [SELECT Id, Rent__c FROM Property__c LIMIT 1];

        GeoMock updateMock = new GeoMock();
        Test.setMock(HttpCalloutMock.class, updateMock);
        Test.startTest();
        prop.Rent__c = 123456;
        update prop;
        Test.stopTest();

        Assert.areEqual(0, updateMock.calloutCount, 'Non-address change does not re-trigger geocoding');
    }

    @IsTest
    static void testLocationUpdateDoesNotReenter() {
        Property__c prop = [SELECT Id FROM Property__c LIMIT 1];

        GeoMock updateMock = new GeoMock();
        Test.setMock(HttpCalloutMock.class, updateMock);
        Test.startTest();
        prop.Location__Latitude__s = 1.0;
        prop.Location__Longitude__s = 1.0;
        update prop;
        Test.stopTest();

        Assert.areEqual(0, updateMock.calloutCount, 'Writing Location does not re-trigger geocoding');
    }
}