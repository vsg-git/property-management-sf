import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createProperty from '@salesforce/apex/PropertyController.createProperty';

const STATUS_OPTIONS = [
    { label: 'Available', value: 'Available' },
    { label: 'Occupied', value: 'Occupied' }
];

const TYPE_OPTIONS = [
    { label: 'Residential', value: 'Residential' },
    { label: 'Commercial', value: 'Commercial' }
];

const FURNISHING_OPTIONS = [
    { label: 'Furnished', value: 'Furnished' },
    { label: 'Semi-Furnished', value: 'Semi-Furnished' },
    { label: 'Unfurnished', value: 'Unfurnished' }
];

export default class PropertyCreate extends NavigationMixin(LightningElement) {
    @track form = {
        Name: '',
        Street__c: '',
        City__c: '',
        State__c: '',
        Postal_Code__c: '',
        Country__c: '',
        Type__c: 'Residential',
        Furnishing_Status__c: 'Furnished',
        Status__c: 'Available',
        Rent__c: null,
        Description__c: ''
    };

    statusOptions = STATUS_OPTIONS;
    typeOptions = TYPE_OPTIONS;
    furnishingOptions = FURNISHING_OPTIONS;

    @track selectedFiles = [];
    fileError = false;
    isSaving = false;

    get hasFiles() {
        return this.selectedFiles.length > 0;
    }

    get selectedFileNames() {
        return this.selectedFiles.map((file) => file.fileName).join(', ');
    }

    get fileSummary() {
        const count = this.selectedFiles.length;
        return `${count} file${count === 1 ? '' : 's'} selected: ${this.selectedFileNames}`;
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this.form = { ...this.form, [field]: event.target.value };
    }

    handlePicklistChange(event) {
        const field = event.target.dataset.field;
        this.form = { ...this.form, [field]: event.detail.value };
    }

    async handleFilesChange(event) {
        const files = Array.from(event.target.files || []);
        if (files.length === 0) {
            return;
        }
        const readers = files.map((file) => this.readFile(file));
        const results = await Promise.all(readers);
        this.selectedFiles = [...this.selectedFiles, ...results];
        if (this.hasFiles) {
            this.fileError = false;
        }
    }

    readFile(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const result = reader.result || '';
                const base64Data = result.substring(result.indexOf(',') + 1);
                resolve({ fileName: file.name, base64Data });
            };
            reader.onerror = () => reject(reader.error);
            reader.readAsDataURL(file);
        });
    }

    handleClear() {
        this.form = {
            Name: '',
            Street__c: '',
            City__c: '',
            State__c: '',
            Postal_Code__c: '',
            Country__c: '',
            Type__c: 'Residential',
            Furnishing_Status__c: 'Furnished',
            Status__c: 'Available',
            Rent__c: null,
            Description__c: ''
        };
        this.selectedFiles = [];
        this.fileError = false;
        const fileInput = this.template.querySelector('lightning-input[data-id="fileInput"]');
        if (fileInput) {
            fileInput.value = null;
        }
    }

    get inputFields() {
        return [
            ...this.template.querySelectorAll(
                'lightning-input, lightning-combobox, lightning-textarea'
            )
        ];
    }

    validateFields() {
        return this.inputFields.reduce((valid, field) => {
            field.reportValidity();
            return valid && field.checkValidity();
        }, true);
    }

    async handleSubmit() {
        if (!this.validateFields()) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Missing required fields',
                    message: 'Please complete all required fields before saving.',
                    variant: 'error'
                })
            );
            return;
        }

        if (!this.hasFiles) {
            this.fileError = true;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Image required',
                    message: 'Please upload at least one image before saving.',
                    variant: 'error'
                })
            );
            return;
        }

        this.isSaving = true;
        try {
            const recordId = await createProperty({
                propertyJson: JSON.stringify(this.form),
                files: this.selectedFiles
            });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Property created.',
                    variant: 'success'
                })
            );
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId,
                    objectApiName: 'Property__c',
                    actionName: 'view'
                }
            });
        } catch (error) {
            const message =
                error && error.body && error.body.message
                    ? error.body.message
                    : 'Unable to create the property.';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message,
                    variant: 'error'
                })
            );
        } finally {
            this.isSaving = false;
        }
    }
}