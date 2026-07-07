import { LightningElement, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import JSPDF from '@salesforce/resourceUrl/jsPDF';
import getLeaseData from '@salesforce/apex/LeaseAgreementController.getLeaseData';
import sendLeaseEmail from '@salesforce/apex/LeaseAgreementController.sendLeaseEmail';

export default class LeaseAgreementPdf extends LightningElement {
    @api recordId;
    loading = false;
    jsPdfInitialized = false;

    renderedCallback() {
        if (this.jsPdfInitialized) {
            return;
        }
        this.jsPdfInitialized = true;
        loadScript(this, JSPDF).catch((error) => {
            this.jsPdfInitialized = false;
            this.showToast('Error', this.reduceError(error), 'error');
        });
    }

    async handleDownload() {
        this.loading = true;
        try {
            const data = await getLeaseData({ recordId: this.recordId });
            const doc = this.buildPdf(data);
            doc.save(this.buildFileName(data));
            this.showToast('Success', 'Lease agreement PDF downloaded.', 'success');
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.loading = false;
        }
    }

    async handleSend() {
        this.loading = true;
        try {
            const data = await getLeaseData({ recordId: this.recordId });
            const doc = this.buildPdf(data);
            const dataUri = doc.output('datauristring');
            const base64 = dataUri.substring(dataUri.indexOf(',') + 1);
            const fileName = this.buildFileName(data);
            const result = await sendLeaseEmail({
                recordId: this.recordId,
                pdfBase64: base64,
                fileName
            });
            this.showToast('Success', result, 'success');
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.loading = false;
        }
    }

    buildPdf(data) {
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF();
        let y = 20;

        doc.setFontSize(18);
        doc.text('Lease Agreement', 105, y, { align: 'center' });
        y += 8;
        doc.setFontSize(11);
        doc.text(data.leaseName || '', 105, y, { align: 'center' });
        y += 12;

        doc.setFontSize(12);
        doc.text('Parties', 20, y);
        y += 7;
        doc.setFontSize(10);
        doc.text('Landlord / Property: ' + (data.propertyName || ''), 20, y);
        y += 6;
        doc.text('Tenant: ' + (data.tenantName || ''), 20, y);
        y += 6;
        doc.text('Tenant Email: ' + (data.tenantEmail || ''), 20, y);
        y += 12;

        doc.setFontSize(12);
        doc.text('Property', 20, y);
        y += 7;
        doc.setFontSize(10);
        const addressLines = doc.splitTextToSize('Address: ' + (data.propertyAddress || ''), 170);
        doc.text(addressLines, 20, y);
        y += addressLines.length * 6;
        doc.text('Listed Rent: ' + this.formatCurrency(data.propertyRent), 20, y);
        y += 12;

        doc.setFontSize(12);
        doc.text('Financials & Term', 20, y);
        y += 7;
        doc.setFontSize(10);
        doc.text('Agreed Monthly Rent: ' + this.formatCurrency(data.agreedMonthlyRent), 20, y);
        y += 6;
        doc.text('Start Date: ' + (data.startDate || ''), 20, y);
        y += 6;
        doc.text('End Date: ' + (data.endDate || ''), 20, y);
        y += 12;

        doc.setFontSize(12);
        doc.text('Terms & Conditions', 20, y);
        y += 7;
        doc.setFontSize(10);
        const termsLines = doc.splitTextToSize(data.terms || 'No terms specified.', 170);
        doc.text(termsLines, 20, y);

        return doc;
    }

    buildFileName(data) {
        const base = data && data.leaseName ? data.leaseName : 'Lease_Agreement';
        return base.replace(/[^a-zA-Z0-9_-]/g, '_') + '.pdf';
    }

    formatCurrency(value) {
        if (value === undefined || value === null) {
            return '';
        }
        return 'INR ' + Number(value).toLocaleString('en-IN');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'An unexpected error occurred.';
    }
}