import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getProperties from '@salesforce/apex/PropertyController.getProperties';

const COLUMNS = [
    {
        label: 'Name',
        fieldName: 'Name',
        type: 'button',
        sortable: true,
        typeAttributes: {
            label: { fieldName: 'Name' },
            variant: 'base',
            name: 'view'
        }
    },
    { label: 'Address', fieldName: 'Street__c', type: 'text', sortable: true },
    { label: 'City', fieldName: 'City__c', type: 'text', sortable: true },
    { label: 'Status', fieldName: 'Status__c', type: 'text', sortable: true },
    { label: 'Furnishing', fieldName: 'Furnishing_Status__c', type: 'text', sortable: true },
    {
        label: 'Rent',
        fieldName: 'Rent__c',
        type: 'currency',
        typeAttributes: { currencyCode: 'INR' },
        sortable: true
    }
];

const PAGE_SIZE = 25;

const STATUS_OPTIONS = [
    { label: 'All', value: '' },
    { label: 'Available', value: 'Available' },
    { label: 'Occupied', value: 'Occupied' }
];

const FURNISHING_OPTIONS = [
    { label: 'All', value: '' },
    { label: 'Furnished', value: 'Furnished' },
    { label: 'Semi-Furnished', value: 'Semi-Furnished' },
    { label: 'Unfurnished', value: 'Unfurnished' }
];

export default class PropertyList extends NavigationMixin(LightningElement) {
    @track records = [];

    columns = COLUMNS;
    statusOptions = STATUS_OPTIONS;
    furnishingOptions = FURNISHING_OPTIONS;

    totalCount = 0;
    isLoading = false;
    errorMessage;

    showFilters = false;
    sortedBy;
    sortedDirection = 'asc';

    minPrice;
    maxPrice;
    status = '';
    furnishingStatus = '';
    radiusKm;
    latitude;
    longitude;

    pageCursors = [null];
    pageIndex = 0;

    connectedCallback() {
        this.loadPage();
    }

    get filterToggleLabel() {
        return this.showFilters ? 'Hide Filters' : 'Show Filters';
    }

    get isSorted() {
        return !!this.sortedBy;
    }

    get showEmptyState() {
        return !this.isLoading && this.records.length === 0;
    }

    get filtersJson() {
        const filters = {};
        if (this.minPrice !== undefined && this.minPrice !== null && this.minPrice !== '') {
            filters.minPrice = this.minPrice;
        }
        if (this.maxPrice !== undefined && this.maxPrice !== null && this.maxPrice !== '') {
            filters.maxPrice = this.maxPrice;
        }
        if (this.status) {
            filters.status = this.status;
        }
        if (this.furnishingStatus) {
            filters.furnishingStatus = this.furnishingStatus;
        }
        if (this.radiusKm && this.latitude !== undefined && this.longitude !== undefined) {
            filters.latitude = this.latitude;
            filters.longitude = this.longitude;
            filters.radiusKm = this.radiusKm;
        }
        return JSON.stringify(filters);
    }

    get hasNext() {
        return (this.pageIndex + 1) * PAGE_SIZE < this.totalCount;
    }

    get hasPrevious() {
        return this.pageIndex > 0;
    }

    get disableNext() {
        return !this.hasNext;
    }

    get disablePrevious() {
        return !this.hasPrevious;
    }

    get showingLabel() {
        const start = this.totalCount === 0 ? 0 : this.pageIndex * PAGE_SIZE + 1;
        const end = this.pageIndex * PAGE_SIZE + this.records.length;
        return `Showing ${start}-${end} of ${this.totalCount}`;
    }

    toggleFilters() {
        this.showFilters = !this.showFilters;
    }

    handleMinPrice(event) {
        this.minPrice = event.target.value;
    }

    handleMaxPrice(event) {
        this.maxPrice = event.target.value;
    }

    handleStatus(event) {
        this.status = event.detail.value;
    }

    handleFurnishing(event) {
        this.furnishingStatus = event.detail.value;
    }

    handleRadius(event) {
        this.radiusKm = event.target.value;
    }

    handleApplyFilters() {
        this.resetPaging();
        if (this.radiusKm) {
            this.captureLocationAndLoad();
        } else {
            this.loadPage();
        }
    }

    handleClearFilters() {
        this.minPrice = undefined;
        this.maxPrice = undefined;
        this.status = '';
        this.furnishingStatus = '';
        this.radiusKm = undefined;
        this.latitude = undefined;
        this.longitude = undefined;
        this.resetPaging();
        this.loadPage();
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
        this.resetPaging();
        this.loadPage();
    }

    handleNext() {
        if (this.hasNext) {
            this.pageIndex += 1;
            this.loadPage();
        }
    }

    handlePrevious() {
        if (this.pageIndex > 0) {
            this.pageIndex -= 1;
            this.loadPage();
        }
    }

    handleRowAction(event) {
        const row = event.detail.row;
        if (row && row.Id) {
            this.navigateToRecord(row.Id);
        }
    }

    async loadPage() {
        this.isLoading = true;
        this.errorMessage = undefined;
        try {
            const result = await getProperties({
                filtersJson: this.filtersJson,
                sortBy: this.sortedBy || null,
                sortDirection: this.sortedDirection,
                lastRecordId: this.isSorted ? null : this.pageCursors[this.pageIndex],
                pageNumber: this.pageIndex,
                pageSize: PAGE_SIZE
            });
            this.records = result.records;
            this.totalCount = result.totalCount;
            if (!this.isSorted) {
                if (this.pageCursors.length === this.pageIndex + 1) {
                    this.pageCursors.push(result.lastRecordId);
                } else {
                    this.pageCursors[this.pageIndex + 1] = result.lastRecordId;
                }
            }
        } catch (error) {
            this.errorMessage = this.reduceError(error);
            this.records = [];
            this.totalCount = 0;
        } finally {
            this.isLoading = false;
        }
    }

    reduceError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return 'An unexpected error occurred.';
    }

    captureLocationAndLoad() {
        if (navigator && navigator.geolocation) {
            this.isLoading = true;
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    this.latitude = position.coords.latitude;
                    this.longitude = position.coords.longitude;
                    this.loadPage();
                },
                () => {
                    this.errorMessage =
                        'Unable to access your location. Please allow location access to use the Nearby filter.';
                    this.isLoading = false;
                }
            );
        } else {
            this.errorMessage = 'Geolocation is not supported by this browser.';
            this.isLoading = false;
        }
    }

    resetPaging() {
        this.pageCursors = [null];
        this.pageIndex = 0;
    }

    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName: 'Property__c',
                actionName: 'view'
            }
        });
    }
}