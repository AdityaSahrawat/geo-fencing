import React, { useEffect } from "react";
import axios from "axios";
import io from "socket.io-client";

const socket = io("http://localhost:5000"); // Backend URL

const Student = () => {
  // Listen for attendance requests
  useEffect(() => {
    socket.on("requestCoordinates", (data) => {
      console.log("Attendance requested for:", data);

      // Fetch student's coordinates
      navigator.geolocation.getCurrentPosition(
        (position) => {
          const { latitude, longitude } = position.coords;
          console.log("Student Coordinates:", latitude, longitude);

          // Send coordinates to the backend
          axios
            .post("/api/attendance/send-coordinates", {
              roomNo: data.roomNo,
              branch: data.branch,
              admissionYear: data.admissionYear,
              latitude,
              longitude,
            })
            .then((response) => {
              console.log(response.data);
            })
            .catch((error) => {
              console.error("Error sending coordinates:", error);
            });
        },
        (error) => {
          console.error("Error fetching coordinates:", error);
        }
      );
    });

    return () => {
      socket.off("requestCoordinates");
    };
  }, []);

  return (
    <div>
      <h1>Student Interface</h1>
      <p>Waiting for attendance request...</p>
    </div>
  );
};

export default Student;