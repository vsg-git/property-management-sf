import { LightningElement, api, wire } from 'lwc';
import getProperty from '@salesforce/apex/PropertyController.getProperty';

export default class PropertyMap extends LightningElement {
    @api recordId;

    mapMarkers = [];
    errorMessage;
    zoomLevel = 14;

    @wire(getProperty, { recordId: '$recordId' })
    wiredProperty({ data, error }) {
        if (data) {
            const latitude = data.Location__Latitude__s;
            const longitude = data.Location__Longitude__s;
            if (latitude !== null && latitude !== undefined && longitude !== null && longitude !== undefined) {
                this.mapMarkers = [
                    {
                        location: {
                            Latitude: latitude,
                            Longitude: longitude
                        },
                        title: data.Name,
                        description: `${data.Street__c || ''}, ${data.City__c || ''}`
                    }
                ];
                this.errorMessage = undefined;
            } else {
                this.mapMarkers = [];
                this.errorMessage = 'This property has no location yet.';
            }
        } else if (error) {
            this.mapMarkers = [];
            this.errorMessage = 'Unable to load the property location.';
        }
    }

    get hasMarkers() {
        return this.mapMarkers.length > 0;
    }
}