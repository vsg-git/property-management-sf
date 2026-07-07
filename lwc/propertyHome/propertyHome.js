import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class PropertyHome extends NavigationMixin(LightningElement) {
    @api dashboardId;

    view = 'menu';

    get isMenu() {
        return this.view === 'menu';
    }

    get isList() {
        return this.view === 'list';
    }

    get isCreate() {
        return this.view === 'create';
    }

    get isDashboard() {
        return this.view === 'dashboard';
    }

    get listVariant() {
        return this.view === 'list' ? 'brand' : 'neutral';
    }

    get createVariant() {
        return this.view === 'create' ? 'brand' : 'neutral';
    }

    get dashboardVariant() {
        return this.view === 'dashboard' ? 'brand' : 'neutral';
    }

    get hasDashboard() {
        return Boolean(this.dashboardId);
    }

    showList() {
        this.view = 'list';
    }

    showCreate() {
        this.view = 'create';
    }

    showDashboard() {
        this.view = 'dashboard';
    }

    openDashboard() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.dashboardId,
                objectApiName: 'Dashboard',
                actionName: 'view'
            }
        });
    }
}