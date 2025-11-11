import React from 'react';
import Modal from '../ui/Modal';
import { Loader } from 'lucide-react';

const EditStudentModal = ({ isOpen, onClose, currentStudent, handleSubmit, formLoading }) => {
    if (!currentStudent) return null;

    return (
        <Modal title="Edit Student" isOpen={isOpen} onClose={onClose}>
            <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                    <label htmlFor="full_name" className="block text-sm font-medium text-base-content-secondary dark:text-dark-base-content-secondary">Full Name</label>
                    <input type="text" name="full_name" id="full_name" defaultValue={currentStudent?.full_name || ''} required className="mt-1 block w-full rounded-lg border-base-300 dark:border-dark-base-300 bg-base-100 dark:bg-dark-base-200 text-base-content dark:text-dark-base-content shadow-sm focus:border-primary focus:ring-primary sm:text-sm" />
                </div>
                <div>
                    <label htmlFor="email" className="block text-sm font-medium text-base-content-secondary dark:text-dark-base-content-secondary">Email</label>
                    <input type="email" name="email" id="email" defaultValue={currentStudent?.email || ''} required className="mt-1 block w-full rounded-lg border-base-300 dark:border-dark-base-300 bg-base-200 dark:bg-dark-base-300 text-base-content-secondary dark:text-dark-base-content-secondary shadow-sm focus:border-primary focus:ring-primary sm:text-sm" readOnly disabled />
                    <p className="mt-1 text-xs text-base-content-secondary">Email cannot be changed after creation.</p>
                </div>
                <div>
                    <label htmlFor="course" className="block text-sm font-medium text-base-content-secondary dark:text-dark-base-content-secondary">Course</label>
                    <input type="text" name="course" id="course" defaultValue={currentStudent?.course || ''} required className="mt-1 block w-full rounded-lg border-base-300 dark:border-dark-base-300 bg-base-100 dark:bg-dark-base-200 text-base-content dark:text-dark-base-content shadow-sm focus:border-primary focus:ring-primary sm:text-sm" />
                </div>
                <div>
                    <label htmlFor="phone" className="block text-sm font-medium text-base-content-secondary dark:text-dark-base-content-secondary">Phone Number</label>
                    <input type="tel" name="phone" id="phone" defaultValue={currentStudent?.phone || ''} required className="mt-1 block w-full rounded-lg border-base-300 dark:border-dark-base-300 bg-base-100 dark:bg-dark-base-200 text-base-content dark:text-dark-base-content shadow-sm focus:border-primary focus:ring-primary sm:text-sm" />
                </div>
                <div className="flex justify-end pt-4 space-x-3">
                    <button type="button" onClick={onClose} className="inline-flex justify-center py-2 px-4 border border-base-300 dark:border-dark-base-300 shadow-sm text-sm font-medium rounded-lg text-base-content dark:text-dark-base-content bg-base-100 dark:bg-dark-base-200 hover:bg-base-200 dark:hover:bg-dark-base-300">Cancel</button>
                    <button type="submit" disabled={formLoading} className="inline-flex justify-center items-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-lg text-primary-content bg-primary hover:bg-primary-focus disabled:opacity-50">
                        {formLoading && <Loader className="animate-spin h-4 w-4 mr-2" />}
                        Save Changes
                    </button>
                </div>
            </form>
        </Modal>
    );
};

export default EditStudentModal;
