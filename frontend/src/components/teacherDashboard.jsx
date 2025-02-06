import { useState, useEffect } from 'react';
import axios from 'axios';
import { io } from 'socket.io-client';

const socket = io('http://10.0.10.5:5000');

function TeacherDashboard() {
  const [roomNo, setRoomNo] = useState('');
  const [branch, setBranch] = useState('');
  const [admissionYear, setAdmissionYear] = useState('');
  const [attendanceResults, setAttendanceResults] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const [sessionActive, setSessionActive] = useState(false);

  useEffect(() => {
    // Listen for individual student updates
    socket.on('attendanceUpdate', (data) => {
      console.log('Received attendance update:', data);
      setAttendanceResults((prev) => {
        const updated = [...prev];
        const index = updated.findIndex(s => s.email === data.email);
        if (index !== -1) {
          updated[index] = {
            ...updated[index],
            studentId: data.studentId,
            status: data.status,
            coordinates: data.coordinates
          };
        }
        return updated;
      });
    });

    // Listen for final attendance results
    socket.on('finalAttendance', (data) => {
      console.log('Received final attendance:', data);
      setAttendanceResults(data.attendance);
      setSessionActive(false);
      setIsLoading(false);
    });

    // Listen for initial student list
    socket.on('attendanceStarted', (data) => {
      console.log('Attendance started:', data);
      const initialStudents = data.students.map((email) => ({
        email,
        studentId: '', // Will be updated when student responds
        status: 'Pending',
      }));
      setAttendanceResults(initialStudents);
      setSessionActive(true);
    });

    return () => {
      socket.off('attendanceUpdate');
      socket.off('finalAttendance');
      socket.off('attendanceStarted');
    };
  }, []);

  const startAttendance = async () => {
    if (!roomNo || !branch || !admissionYear) {
      setError('Please fill in all fields');
      return;
    }

    setError('');
    setIsLoading(true);
    setAttendanceResults([]); // Clear previous results

    try {
      await axios.post('http://10.0.10.5:5000/api/attendance/start', 
        { roomNo, branch, admissionYear },
        { headers: { Authorization: `Bearer ${localStorage.getItem('token')}` } }
      );
    } catch (error) {
      console.error('Error starting attendance:', error);
      setError('Failed to start attendance. Please try again.');
      setIsLoading(false);
      setSessionActive(false);
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'Present':
        return 'bg-green-50 text-green-600';
      case 'Absent':
        return 'bg-red-50 text-red-600';
      default:
        return 'bg-yellow-50 text-yellow-600';
    }
  };

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold mb-6">Teacher Dashboard</h1>
      
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-xl font-semibold mb-4">Take Attendance</h2>
          {error && (
            <div className="mb-4 p-3 bg-red-50 text-red-600 rounded-lg">
              {error}
            </div>
          )}
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Room Number
              </label>
              <input
                type="text"
                value={roomNo}
                onChange={(e) => setRoomNo(e.target.value)}
                className="w-full p-2 border rounded-lg"
                placeholder="Enter room number"
                disabled={sessionActive}
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Branch
              </label>
              <input
                type="text"
                value={branch}
                onChange={(e) => setBranch(e.target.value)}
                className="w-full p-2 border rounded-lg"
                placeholder="Enter branch"
                disabled={sessionActive}
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Admission Year
              </label>
              <input
                type="text"
                value={admissionYear}
                onChange={(e) => setAdmissionYear(e.target.value)}
                className="w-full p-2 border rounded-lg"
                placeholder="Enter admission year"
                disabled={sessionActive}
              />
            </div>
            <button
              onClick={startAttendance}
              disabled={isLoading || sessionActive}
              className={`w-full p-3 rounded-lg text-white font-medium ${
                isLoading || sessionActive
                  ? 'bg-blue-400 cursor-not-allowed'
                  : 'bg-blue-600 hover:bg-blue-700'
              }`}
            >
              {isLoading ? 'Processing...' : sessionActive ? 'Session Active' : 'Take Attendance'}
            </button>
          </div>
        </div>

        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-xl font-semibold mb-4">
            Attendance Results
            {sessionActive && <span className="text-sm font-normal text-blue-600 ml-2">(Live)</span>}
          </h2>
          {attendanceResults.length > 0 ? (
            <div className="space-y-3">
              {attendanceResults.map((student, index) => (
                <div
                  key={index}
                  className={`p-4 rounded-lg ${getStatusColor(student.status)}`}
                >
                  <p className="font-medium">Email: {student.email}</p>
                  <p className="text-sm">Status: {student.status}</p>
                  {student.coordinates && (
                    <p className="text-xs mt-1">
                      Location: ({student.coordinates.latitude.toFixed(6)}, {student.coordinates.longitude.toFixed(6)})
                    </p>
                  )}
                </div>
              ))}
            </div>
          ) : (
            <p className="text-gray-500 text-center py-4">
              No attendance results yet
            </p>
          )}
        </div> 
      </div>
    </div>
  );
}

export default TeacherDashboard;