public with sharing class GeocodingService implements Queueable, Database.AllowsCallouts {
    private Set<Id> propertyIds;

    public GeocodingService(Set<Id> propertyIds) {
        this.propertyIds = propertyIds;
    }

    public void execute(QueueableContext context) {
        if (propertyIds == null || propertyIds.isEmpty()) {
            return;
        }

        List<Property__c> properties = [
            SELECT Id, Street__c, City__c, State__c, Postal_Code__c, Country__c,
                Location__Latitude__s, Location__Longitude__s
            FROM Property__c
            WHERE Id IN :propertyIds
        ];

        List<Property__c> toUpdate = new List<Property__c>();

        for (Property__c prop : properties) {
            if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
                break;
            }
            try {
                Map<String, Decimal> coordinates = geocode(prop);
                if (coordinates != null) {
                    prop.Location__Latitude__s = coordinates.get('lat');
                    prop.Location__Longitude__s = coordinates.get('lon');
                    toUpdate.add(prop);
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, 'Geocoding failed for ' + prop.Id + ': ' + ex.getMessage());
            }
        }

        if (!toUpdate.isEmpty()) {
            PropertyTriggerHandler.bypassGeocoding = true;
            try {
                update toUpdate;
            } finally {
                PropertyTriggerHandler.bypassGeocoding = false;
            }
        }
    }

    private Map<String, Decimal> geocode(Property__c prop) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(prop.Street__c)) {
            parts.add(prop.Street__c);
        }
        if (String.isNotBlank(prop.City__c)) {
            parts.add(prop.City__c);
        }
        if (String.isNotBlank(prop.State__c)) {
            parts.add(prop.State__c);
        }
        if (String.isNotBlank(prop.Postal_Code__c)) {
            parts.add(prop.Postal_Code__c);
        }
        if (String.isNotBlank(prop.Country__c)) {
            parts.add(prop.Country__c);
        }
        if (parts.isEmpty()) {
            return null;
        }

        String query = EncodingUtil.urlEncode(String.join(parts, ', '), 'UTF-8');
        String endpoint = 'https://nominatim.openstreetmap.org/search?format=json&limit=1&q=' + query;

        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setHeader('User-Agent', 'PropertyMgmt/1.0');

        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() != 200) {
            return null;
        }

        List<Object> results = (List<Object>) JSON.deserializeUntyped(response.getBody());
        if (results == null || results.isEmpty()) {
            return null;
        }

        Map<String, Object> first = (Map<String, Object>) results[0];
        Object latValue = first.get('lat');
        Object lonValue = first.get('lon');
        if (latValue == null || lonValue == null) {
            return null;
        }

        Map<String, Decimal> coordinates = new Map<String, Decimal>();
        coordinates.put('lat', Decimal.valueOf(String.valueOf(latValue)));
        coordinates.put('lon', Decimal.valueOf(String.valueOf(lonValue)));
        return coordinates;
    }
}