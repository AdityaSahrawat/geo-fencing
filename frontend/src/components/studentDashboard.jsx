import { useState, useEffect } from "react";
import axios from "axios";
import { io } from "socket.io-client";

const socket = io("http://34.60.77.234:5000");

function StudentDashboard() {
  const [attendanceHistory, setAttendanceHistory] = useState([]);
  const [status, setStatus] = useState("Waiting for attendance request...");
  const [loading, setLoading] = useState(true);
  const [location, setLocation] = useState(null);
  const [studentId, setStudentId] = useState('');

  useEffect(() => {
    fetchAttendanceHistory();

    // Retrieve student ID from token
    const token = localStorage.getItem("token");
    if (token) {
      try {
        const decoded = JSON.parse(atob(token.split(".")[1])); // Decode JWT
        const studentId = decoded.id;
        setStudentId(studentId);
        socket.emit("joinRoom", studentId);
      } catch (error) {
        console.error("Error decoding token:", error);
      }
    }

    socket.on("attendanceStarted", async (data) => {
      setStatus("Processing attendance request...");
      try {
        const position = await getCurrentPosition();
        if (!position || !position.coords) {
          throw new Error("Could not retrieve position data.");
        }
    
        setLocation(position);
    
        const { latitude, longitude } = position.coords;
        const token = localStorage.getItem("token");
    
        if (!token) {
          setStatus("Error: No token found!");
          console.error("No token in localStorage!");
          return;
        }
    
        const response = await axios.post(
          "http://34.60.77.234:5000/api/attendance/send-coordinates",
          {
            roomNo: data.roomNo,
            branch: data.branch,
            admissionYear: data.admissionYear,
            latitude,
            longitude,
            studentId // Include studentId in the request
          },
          {
            headers: { Authorization: `Bearer ${token}` },
          }
        );
    
        setStatus(`Attendance ${response.data.status}: ${response.data.message}`);
      } catch (error) {
        console.error("Error processing attendance:", error);
        setStatus("Failed to record attendance. Please try again.");
      }
    });

    socket.on("attendanceResult", (data) => {
      setStatus(`Attendance Status: ${data.message}`);
    });

    return () => {
      socket.off("attendanceStarted");
      socket.off("attendanceResult");
    };
  }, []);

  const getCurrentPosition = () => {
    return new Promise((resolve, reject) => {
      if (!navigator.geolocation) {
        reject(new Error("Geolocation is not supported by your browser"));
        return;
      }
      navigator.geolocation.getCurrentPosition(
        (position) => {
          console.log("Position retrieved:", position);
          resolve(position);
        },
        (error) => {
          console.error("Geolocation error:", error);
          reject(error);
        },
        {
          enableHighAccuracy: true,
          timeout: 15000, // Increased timeout
          maximumAge: 0, // Avoid using cached location
        }
      );
    });
  };

  const fetchAttendanceHistory = async () => {
    setLoading(true);
    try {
      const response = await axios.get("http://34.60.77.234:5000/api/attendance/history", {
        headers: { Authorization: `Bearer ${localStorage.getItem("token")}` },
      });
      setAttendanceHistory(response.data);
    } catch (error) {
      console.error("Error fetching attendance history:", error);
    }
    setLoading(false);
  };

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold mb-6">Student Dashboard</h1>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Attendance Status */}
        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-xl font-semibold mb-4">Current Status</h2>
          <div className="p-4 bg-gray-50 rounded-lg">
            <p className="text-lg">{status}</p>
          </div>
        </div>

        {/* Attendance History */}
        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-xl font-semibold mb-4">Attendance History</h2>
          {loading ? (
            <p className="text-gray-600">Loading attendance history...</p>
          ) : (
            <div className="space-y-2">
              {attendanceHistory.length > 0 ? (
                attendanceHistory.map((record) => (
                  <div
                    key={record._id}
                    className={`p-4 rounded-lg ${
                      record.isPresent ? "bg-green-50" : "bg-red-50"
                    }`}
                  >
                    <p className="font-medium">{record.class?.name || "Class"}</p>
                    <p className="text-sm text-gray-600">
                      {new Date(record.date).toLocaleDateString()}{" "}
                      <span className={record.isPresent ? "text-green-600" : "text-red-600"}>
                        {record.isPresent ? "Present" : "Absent"}
                      </span>
                    </p>
                  </div>
                ))
              ) : (
                <p className="text-gray-600">No attendance records found.</p>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Display Coordinates */}
      {location && (
        <div className="mt-6 p-4 bg-white rounded-lg shadow">
          <h2 className="text-lg font-semibold mb-2">Current Location</h2>
          <p className="text-gray-700">
            Latitude: {location.coords.latitude.toFixed(6)}<br />
            Longitude: {location.coords.longitude.toFixed(6)}
          </p>
        </div>
      )}
    </div>
  );
}

export default StudentDashboard;