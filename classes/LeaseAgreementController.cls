public with sharing class LeaseAgreementController {
    public class LeaseData {
        @AuraEnabled public String leaseName;
        @AuraEnabled public String terms;
        @AuraEnabled public Decimal agreedMonthlyRent;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public String propertyName;
        @AuraEnabled public String propertyAddress;
        @AuraEnabled public Decimal propertyRent;
        @AuraEnabled public String tenantName;
        @AuraEnabled public String tenantEmail;
    }

    @AuraEnabled(cacheable=true)
    public static LeaseData getLeaseData(Id recordId) {
        List<Lease_Agreement__c> leases = [
            SELECT Id, Name, Terms__c, Agreed_Monthly_Rent__c, Start_Date__c, End_Date__c,
                Property__r.Name, Property__r.Street__c, Property__r.City__c, Property__r.State__c,
                Property__r.Postal_Code__c, Property__r.Country__c, Property__r.Rent__c,
                Tenant__r.Name, Tenant__r.Email__c
            FROM Lease_Agreement__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        if (leases.isEmpty()) {
            throw new AuraHandledException('Lease agreement not found.');
        }

        Lease_Agreement__c lease = leases[0];
        LeaseData data = new LeaseData();
        data.leaseName = lease.Name;
        data.terms = lease.Terms__c;
        data.agreedMonthlyRent = lease.Agreed_Monthly_Rent__c;
        data.startDate = lease.Start_Date__c;
        data.endDate = lease.End_Date__c;
        data.propertyName = lease.Property__r != null ? lease.Property__r.Name : null;
        data.propertyRent = lease.Property__r != null ? lease.Property__r.Rent__c : null;
        data.propertyAddress = buildAddress(lease);
        data.tenantName = lease.Tenant__r != null ? lease.Tenant__r.Name : null;
        data.tenantEmail = lease.Tenant__r != null ? lease.Tenant__r.Email__c : null;
        return data;
    }

    @AuraEnabled
    public static String sendLeaseEmail(Id recordId, String pdfBase64, String fileName) {
        if (String.isBlank(pdfBase64)) {
            throw new AuraHandledException('No PDF content was provided to attach.');
        }

        List<Lease_Agreement__c> leases = [
            SELECT Id, Name, Tenant__r.Name, Tenant__r.Email__c
            FROM Lease_Agreement__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        if (leases.isEmpty()) {
            throw new AuraHandledException('Lease agreement not found.');
        }

        Lease_Agreement__c lease = leases[0];
        String tenantEmail = lease.Tenant__r != null ? lease.Tenant__r.Email__c : null;
        if (String.isBlank(tenantEmail)) {
            throw new AuraHandledException('Tenant email address is missing. Cannot send the lease agreement.');
        }

        String attachmentName = String.isNotBlank(fileName) ? fileName : (lease.Name + '.pdf');

        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(attachmentName);
        attachment.setBody(EncodingUtil.base64Decode(pdfBase64));
        attachment.setContentType('application/pdf');

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ tenantEmail });
        email.setSubject('Lease Agreement ' + lease.Name);
        email.setPlainTextBody(
            'Dear ' +
            (lease.Tenant__r != null ? lease.Tenant__r.Name : 'Tenant') +
            ',\n\nPlease find attached the lease agreement ' +
            lease.Name +
            '.\n\nRegards,\nProperty Management Team'
        );
        email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attachment });

        List<Messaging.SendEmailResult> results = Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{ email }
        );

        if (!results.isEmpty() && !results[0].isSuccess()) {
            throw new AuraHandledException('Failed to send the lease agreement email.');
        }

        return 'Lease agreement sent to ' + tenantEmail;
    }

    private static String buildAddress(Lease_Agreement__c lease) {
        if (lease.Property__r == null) {
            return null;
        }
        List<String> parts = new List<String>();
        if (String.isNotBlank(lease.Property__r.Street__c)) {
            parts.add(lease.Property__r.Street__c);
        }
        if (String.isNotBlank(lease.Property__r.City__c)) {
            parts.add(lease.Property__r.City__c);
        }
        if (String.isNotBlank(lease.Property__r.State__c)) {
            parts.add(lease.Property__r.State__c);
        }
        if (String.isNotBlank(lease.Property__r.Postal_Code__c)) {
            parts.add(lease.Property__r.Postal_Code__c);
        }
        if (String.isNotBlank(lease.Property__r.Country__c)) {
            parts.add(lease.Property__r.Country__c);
        }
        return String.join(parts, ', ');
    }
}