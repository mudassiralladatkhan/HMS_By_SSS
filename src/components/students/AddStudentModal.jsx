import React, { useState } from 'react';
import { supabase } from '../../lib/supabase';
import Modal from '../ui/Modal';
import { Loader, User, Mail, Lock, Phone, BookOpen, Calendar } from 'lucide-react';
import toast from 'react-hot-toast';

const AddStudentModal = ({ isOpen, onClose, onStudentAdded }) => {
    const [loading, setLoading] = useState(false);
    const [formData, setFormData] = useState({
        fullName: '',
        email: '',
        password: '',
        phone: '',
        course: '',
        joiningDate: new Date().toISOString().slice(0, 10),
    });

    const handleChange = (e) => {
        const { name, value } = e.target;
        setFormData(prev => ({ ...prev, [name]: value }));
    };

    const handleAddStudent = async (e) => {
        e.preventDefault();
        setLoading(true);

        const { fullName, email, password, phone, course, joiningDate } = formData;

        if (password.length < 6) {
            toast.error('Password must be at least 6 characters long.');
            setLoading(false);
            return;
        }
        
        const { data, error } = await supabase.auth.signUp({
            email,
            password,
            options: {
                data: {
                    full_name: fullName,
                    role: 'Student',
                    phone: phone,
                    course: course,
                    joining_date: joiningDate,
                },
                emailRedirectTo: `${window.location.origin}/`
            }
        });

        setLoading(false);

        if (error) {
            toast.error(error.message);
        } else if (data.user && data.user.identities && data.user.identities.length === 0) {
            toast.error('An account with this email already exists. Please use a different email.');
        } else if (data.user) {
            toast.success('Student account created! The user will need to verify their email to log in.');
            onStudentAdded();
            onClose();
        } else {
            toast.error('An unknown error occurred during sign up.');
        }
    };

    return (
        <Modal title="Add New Student" isOpen={isOpen} onClose={onClose}>
            <form onSubmit={handleAddStudent} className="space-y-4">
                <p className="text-sm text-base-content-secondary">
                    This will create a new user account for the student. They will need to verify their email before they can log in.
                </p>
                <div>
                    <label htmlFor="fullName" className="block text-sm font-medium text-base-content-secondary dark:text-dark-base-content-secondary">Full Name</label>
                    <div className="mt-1 relative">
                        <User className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400" />
                        <input type="text" name="fullName" id="fullName" value={formData.fullName} onChange={handleChange} required className="block w-full rounded-lg border-base-300 dark:border-dark-base-300 bg-base-100 dark:bg-dark-base-200 pl-10 py-2 shadow-sm focus:border-primary focus:ring-primary sm:text-sm" />
                    </div>
                </div>
                <div>
                    <label htmlFor="email" className="block text-sm font-medium text-base-content-secondary">Email</label>
                     <div className="mt-1 relative">
                        <Mail className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400" />
                        <input type="email" name="email" id="email" value={formData.email} onChange={handleChange} required className="block w-full rounded-lg border-base-300 dark:border-dark-base-300 bg-base-100 dark:bg-dark-base-200 pl-10 py-2 shadow-sm focus:border-primary focus:ring-primary sm:text-sm" />
                    </div>
                </div>
                 <div>
                    <label htmlFor="password" className="block text-sm font-medium text-base-content-secondary">Temporary Password</label>
                     <div className="mt-1 relative">
                        <Lock className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400" />
                        <input type="password" name="password" id="password" value={formData.password} onChange={handleChange} required className="block w-full rounded-lg border-base-300 dark:border-dark-base-300 bg-base-100 dark:bg-dark-base-200 pl-10 py-2 shadow-sm focus:border-primary focus:ring-primary sm:text-sm" placeholder="Min. 6 characters" />
                    </div>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                        <label htmlFor="phone" className="block text-sm font-medium text-base-content-secondary">Phone Number</label>
                        <div className="mt-1 relative">
                            <Phone className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400" />
                            <input type="tel" name="phone" id="phone" value={formData.phone} onChange={handleChange} required className="block w-full rounded-lg border-base-300 dark:border-dark-base-300 bg-base-100 dark:bg-dark-base-200 pl-10 py-2 shadow-sm focus:border-primary focus:ring-primary sm:text-sm" />
                        </div>
                    </div>
                    <div>
                        <label htmlFor="course" className="block text-sm font-medium text-base-content-secondary">Course</label>
                        <div className="mt-1 relative">
                            <BookOpen className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400" />
                            <input type="text" name="course" id="course" value={formData.course} onChange={handleChange} required className="block w-full rounded-lg border-base-300 dark:border-dark-base-300 bg-base-100 dark:bg-dark-base-200 pl-10 py-2 shadow-sm focus:border-primary focus:ring-primary sm:text-sm" />
                        </div>
                    </div>
                </div>
                <div>
                    <label htmlFor="joiningDate" className="block text-sm font-medium text-base-content-secondary">Joining Date</label>
                    <div className="mt-1 relative">
                        <Calendar className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400" />
                        <input type="date" name="joiningDate" id="joiningDate" value={formData.joiningDate} onChange={handleChange} required className="block w-full rounded-lg border-base-300 dark:border-dark-base-300 bg-base-100 dark:bg-dark-base-200 pl-10 py-2 shadow-sm focus:border-primary focus:ring-primary sm:text-sm" />
                    </div>
                </div>
                <div className="flex justify-end pt-4 space-x-3">
                    <button type="button" onClick={onClose} className="inline-flex justify-center py-2 px-4 border border-base-300 dark:border-dark-base-300 shadow-sm text-sm font-medium rounded-lg text-base-content dark:text-dark-base-content bg-base-100 dark:bg-dark-base-200 hover:bg-base-200 dark:hover:bg-dark-base-300">Cancel</button>
                    <button type="submit" disabled={loading} className="inline-flex justify-center items-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-lg text-primary-content bg-primary hover:bg-primary-focus disabled:opacity-50">
                        {loading ? <Loader className="animate-spin h-4 w-4 mr-2" /> : null}
                        Create Student Account
                    </button>
                </div>
            </form>
        </Modal>
    );
};

export default AddStudentModal;
