import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { BedDouble, Users, Loader, Edit, Trash2 } from 'lucide-react';
import PageHeader from '../components/ui/PageHeader';
import Modal from '../components/ui/Modal';
import EmptyState from '../components/ui/EmptyState';
import toast from 'react-hot-toast';

const statusStyles = {
    Occupied: 'bg-red-500/10 text-red-500 dark:bg-red-500/20 dark:text-red-400',
    Vacant: 'bg-green-500/10 text-green-600 dark:bg-green-500/20 dark:text-green-400',
    Maintenance: 'bg-yellow-500/10 text-yellow-600 dark:bg-yellow-500/20 dark:text-yellow-400',
};

const containerVariants = {
    hidden: { opacity: 0 },
    visible: { opacity: 1, transition: { staggerChildren: 0.05 } }
};

const itemVariants = {
    hidden: { opacity: 0, scale: 0.95, y: 10 },
    visible: { opacity: 1, scale: 1, y: 0 }
};

const RoomsPage = () => {
    const [rooms, setRooms] = useState([]);
    const [allocations, setAllocations] = useState({});
    const [loading, setLoading] = useState(true);
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [formLoading, setFormLoading] = useState(false);
    const [currentRoom, setCurrentRoom] = useState(null);
    const [unallocatedStudents, setUnallocatedStudents] = useState([]);
    const [selectedStudentId, setSelectedStudentId] = useState('');

    const fetchData = async () => {
        // No setLoading(true) here to allow for silent refreshes
        try {
            const [roomsRes, allocationsRes] = await Promise.all([
                supabase.from('rooms').select('*').order('room_number'),
                supabase
                    .from('room_allocations')
                    .select('room_id, profiles(full_name)')
                    .eq('is_active', true)
            ]);
            
            if (roomsRes.error) throw roomsRes.error;
            if (allocationsRes.error) throw allocationsRes.error;

            const allocationsByRoom = (allocationsRes.data || []).reduce((acc, alloc) => {
                if (!alloc.profiles) return acc;
                if (!acc[alloc.room_id]) {
                    acc[alloc.room_id] = [];
                }
                acc[alloc.room_id].push(alloc.profiles.full_name);
                return acc;
            }, {});

            setRooms(roomsRes.data || []);
            setAllocations(allocationsByRoom);
        } catch (error) {
            toast.error(`Failed to fetch data: ${error.message}`);
            console.error("Error fetching data:", error);
            setRooms([]);
            setAllocations({});
        } finally {
            setLoading(false);
        }
    };

    const fetchUnallocatedStudents = async () => {
        try {
            const { data: allStudents, error: studentsError } = await supabase
                .from('profiles')
                .select('id, full_name')
                .eq('role', 'Student')
                .order('full_name');
            if (studentsError) throw studentsError;

            const { data: allocations, error: allocationsError } = await supabase
                .from('room_allocations')
                .select('student_id')
                .eq('is_active', true);
            if (allocationsError) throw allocationsError;

            const allocatedStudentIds = new Set(allocations.map(a => a.student_id));
            const unallocated = allStudents.filter(s => !allocatedStudentIds.has(s.id));
            setUnallocatedStudents(unallocated);
        } catch (error) {
            toast.error(`Failed to fetch students: ${error.message}`);
        }
    };

    useEffect(() => {
        fetchData();
    }, []);
    
    useEffect(() => {
        if (isModalOpen && !currentRoom) {
            fetchUnallocatedStudents();
        }
    }, [isModalOpen, currentRoom]);

    const openAddModal = () => {
        setCurrentRoom(null);
        setSelectedStudentId('');
        setIsModalOpen(true);
    };

    const openEditModal = (room) => {
        setCurrentRoom(room);
        setIsModalOpen(true);
    };

    const closeModal = () => {
        setIsModalOpen(false);
        setSelectedStudentId('');
        setCurrentRoom(null);
    };

    const handleDelete = async (roomId) => {
        const currentOccupants = allocations[roomId] || [];
        if (currentOccupants.length > 0) {
            toast.error('Cannot delete an occupied room. Please deallocate students first.');
            return;
        }

        if (window.confirm('Are you sure you want to delete this room? This action cannot be undone.')) {
            setLoading(true);
            const { error } = await supabase.from('rooms').delete().eq('id', roomId);
            if (error) {
                toast.error(`Failed to delete room: ${error.message}`);
            } else {
                toast.success('Room deleted successfully.');
                fetchData();
            }
            setLoading(false);
        }
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setFormLoading(true);
        const formData = new FormData(e.target);
        const roomData = Object.fromEntries(formData.entries());

        const getCapacity = (type) => {
            if (type === 'Triple') return 3;
            if (type === 'Double') return 2;
            return 1;
        };

        if (currentRoom) { // EDIT LOGIC
            const dataToSubmit = {
                room_number: roomData.roomNumber,
                type: roomData.type,
                status: roomData.status,
                occupants: getCapacity(roomData.type),
            };
            const currentOccupants = allocations[currentRoom.id] || [];
            if (currentOccupants.length > dataToSubmit.occupants) {
                toast.error(`Cannot change type. Room has ${currentOccupants.length} occupants, exceeding new capacity of ${dataToSubmit.occupants}.`);
                setFormLoading(false);
                return;
            }
            const { error } = await supabase.from('rooms').update(dataToSubmit).eq('id', currentRoom.id);
            if (error) {
                toast.error(`Operation failed: ${error.message}`);
            } else {
                toast.success(`Room updated successfully!`);
                closeModal();
                fetchData();
            }
        } else { // ADD LOGIC
            const dataToInsert = {
                room_number: roomData.roomNumber,
                type: roomData.type,
                status: 'Vacant', // Always create as Vacant
                occupants: getCapacity(roomData.type),
            };

            const { data: newRoom, error: insertError } = await supabase
                .from('rooms')
                .insert(dataToInsert)
                .select()
                .single();

            if (insertError) {
                toast.error(`Failed to add room: ${insertError.message}`);
                setFormLoading(false);
                return;
            }

            if (selectedStudentId && newRoom) {
                const { error: rpcError } = await supabase.rpc('allocate_room', {
                    p_student_id: selectedStudentId,
                    p_room_id: newRoom.id,
                });

                if (rpcError) {
                    toast.error(`Room created, but allocation failed: ${rpcError.message}`);
                } else {
                    toast.success('Room added and student allocated successfully!');
                }
            } else {
                toast.success('Room added successfully!');
            }
            closeModal();
            fetchData();
        }
        setFormLoading(false);
    };

    return (
        <>
            <PageHeader
                title="Room Management"
                buttonText="Add Room"
                onButtonClick={openAddModal}
            />
            {loading ? (
                <div className="flex justify-center items-center h-64">
                    <Loader className="animate-spin h-8 w-8 text-primary" />
                </div>
            ) : rooms.length > 0 ? (
                <motion.div
                    className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-6"
                    variants={containerVariants}
                    initial="hidden"
                    animate="visible"
                >
                    {rooms.map(room => {
                        const currentOccupants = allocations[room.id] || [];
                        return (
                            <motion.div
                                key={room.id}
                                variants={itemVariants}
                                whileHover={{ y: -5, scale: 1.03 }}
                                transition={{ type: 'spring', stiffness: 300 }}
                                className="relative bg-base-100 dark:bg-dark-base-200 rounded-2xl shadow-lg p-5 flex flex-col justify-between h-full transition-all duration-300"
                            >
                                <div className="absolute top-3 right-3 flex space-x-1">
                                    <button onClick={() => openEditModal(room)} className="p-1.5 rounded-full text-primary/70 hover:text-primary hover:bg-primary/10 dark:text-dark-primary/70 dark:hover:text-dark-primary dark:hover:bg-dark-primary/10 transition-colors" aria-label="Edit Room">
                                        <Edit className="w-4 h-4" />
                                    </button>
                                    <button onClick={() => handleDelete(room.id)} className="p-1.5 rounded-full text-red-500/70 hover:text-red-500 hover:bg-red-500/10 transition-colors" aria-label="Delete Room">
                                        <Trash2 className="w-4 h-4" />
                                    </button>
                                </div>
                                <div>
                                    <div className="flex justify-between items-start">
                                        <Link to={`/rooms/${room.id}`} className="text-primary hover:text-primary-focus dark:text-dark-primary dark:hover:text-dark-primary-focus">
                                            <h3 className="text-lg font-bold font-heading text-base-content dark:text-dark-base-content pr-16">Room {room.room_number}</h3>
                                        </Link>
                                        <span className={`px-2.5 py-0.5 inline-flex text-xs leading-5 font-semibold rounded-full ${statusStyles[room.status]}`}>
                                            {room.status}
                                        </span>
                                    </div>
                                    <p className="text-sm text-base-content-secondary dark:text-dark-base-content-secondary mt-1">{room.type}</p>
                                </div>
                                <div className="mt-4">
                                    <div className="flex items-center text-sm text-base-content-secondary dark:text-dark-base-content-secondary">
                                        <Users className="w-4 h-4 mr-2" />
                                        <span>
                                            {currentOccupants.length} / {room.occupants} Occupants
                                        </span>
                                    </div>
                                    {currentOccupants.length > 0 && (
                                        <div className="mt-2 text-xs text-base-content-secondary dark:text-dark-base-content-secondary space-y-1">
                                            {currentOccupants.map((name, index) => (
                                                <p key={index} className="truncate">- {name}</p>
                                            ))}
                                        </div>
                                    )}
                                </div>
                            </motion.div>
                        )
                    })}
                </motion.div>
            ) : (
                <div className="bg-base-100 dark:bg-dark-base-200 rounded-2xl shadow-lg">
                    <EmptyState 
                        icon={<BedDouble className="w-full h-full" />}
                        title="No Rooms Found"
                        message="Add a room to get started or check your database policies."
                    />
                </div>
            )}

            <Modal title={currentRoom ? 'Edit Room' : 'Add New Room'} isOpen={isModalOpen} onClose={closeModal}>
                <form onSubmit={handleSubmit} className="space-y-4">
                    <div>
                        <label htmlFor="roomNumber" className="block text-sm font-medium text-base-content-secondary dark:text-dark-base-content-secondary">Room Number</label>
                        <input type="number" name="roomNumber" id="roomNumber" defaultValue={currentRoom?.room_number || ''} required className="mt-1 block w-full rounded-lg border-base-300 dark:border-dark-base-300 bg-base-100 dark:bg-dark-base-200 text-base-content dark:text-dark-base-content shadow-sm focus:border-primary focus:ring-primary sm:text-sm" />
                    </div>
                    <div>
                        <label htmlFor="type" className="block text-sm font-medium text-base-content-secondary dark:text-dark-base-content-secondary">Room Type</label>
                        <select id="type" name="type" defaultValue={currentRoom?.type || 'Single'} required className="mt-1 block w-full rounded-lg border-base-300 dark:border-dark-base-300 bg-base-100 dark:bg-dark-base-200 text-base-content dark:text-dark-base-content shadow-sm focus:border-primary focus:ring-primary sm:text-sm">
                            <option>Single</option>
                            <option>Double</option>
                            <option>Triple</option>
                        </select>
                    </div>
                    
                    {!currentRoom && (
                        <div>
                            <label htmlFor="student_id" className="block text-sm font-medium text-base-content-secondary dark:text-dark-base-content-secondary">Allocate Student (Optional)</label>
                            <select
                                id="student_id"
                                name="student_id"
                                value={selectedStudentId}
                                onChange={(e) => setSelectedStudentId(e.target.value)}
                                className="mt-1 block w-full rounded-lg border-base-300 dark:border-dark-base-300 bg-base-100 dark:bg-dark-base-200 text-base-content dark:text-dark-base-content shadow-sm focus:border-primary focus:ring-primary sm:text-sm"
                            >
                                <option value="">None (Create as Vacant)</option>
                                {unallocatedStudents.length > 0 ? unallocatedStudents.map(student => (
                                    <option key={student.id} value={student.id}>{student.full_name}</option>
                                )) : <option disabled>No unallocated students</option>}
                            </select>
                        </div>
                    )}

                    {currentRoom && (
                        <div>
                            <label htmlFor="status" className="block text-sm font-medium text-base-content-secondary dark:text-dark-base-content-secondary">Status</label>
                            <select id="status" name="status" defaultValue={currentRoom?.status} required className="mt-1 block w-full rounded-lg border-base-300 dark:border-dark-base-300 bg-base-100 dark:bg-dark-base-200 text-base-content dark:text-dark-base-content shadow-sm focus:border-primary focus:ring-primary sm:text-sm">
                                <option value="Vacant">Vacant</option>
                                <option value="Occupied">Occupied</option>
                                <option value="Maintenance">Maintenance</option>
                            </select>
                        </div>
                    )}
                    <div className="flex justify-end pt-4 space-x-3">
                        <button type="button" onClick={closeModal} className="inline-flex justify-center py-2 px-4 border border-base-300 dark:border-dark-base-300 shadow-sm text-sm font-medium rounded-lg text-base-content dark:text-dark-base-content bg-base-100 dark:bg-dark-base-200 hover:bg-base-200 dark:hover:bg-dark-base-300">Cancel</button>
                        <button type="submit" disabled={formLoading} className="inline-flex justify-center items-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-lg text-primary-content bg-primary hover:bg-primary-focus disabled:opacity-50">
                            {formLoading && <Loader className="animate-spin h-4 w-4 mr-2" />}
                            {currentRoom ? 'Save Changes' : 'Add Room'}
                        </button>
                    </div>
                </form>
            </Modal>
        </>
    );
};

export default RoomsPage;
