const express = require("express");
const { attendanceModel, roomModel, studentModel } = require("../mdb");
const { authenticate } = require("../middleware/auth");
const { isPointInPolygon } = require("geolib");
const attendanceR = express.Router();
const ongoingAttendanceSessions = new Map();
// Record attendance
attendanceR.post("/", async (req, res) => {
  const { roomNo, teacherId, students } = req.body;
  try {
    const attendance = new attendanceModel({ roomNo, teacherId, students });
    await attendance.save();
    res.status(201).json({ message: "Attendance recorded successfully", attendance });
  } catch (error) {
    res.status(500).json({ message: "Error recording attendance", error });
  }
});
// Get attendance results
attendanceR.get("/results", authenticate, async (req, res) => {
  const { attendanceId } = req.query;
  try {
    const attendance = await attendanceModel.findById(attendanceId).populate("students.studentId");
    if (!attendance) {
      return res.status(404).json({ message: "Attendance record not found" });
    }
    res.status(200).json({ attendance });
  } catch (error) {
    res.status(500).json({ message: "Error fetching attendance results", error });
  }
});
// Start attendance session
attendanceR.post("/start", authenticate, async (req, res) => {
  const { roomNo, branch, admissionYear } = req.body;
  const teacherId = req.user.id;

  try {
    const room = await roomModel.findOne({ roomNo });
    if (!room) {
      return res.status(404).json({ message: "Room not found." });
    }

    console.log('Room coordinates:', room.coordinates);

    const students = await studentModel.find({ branch, admissionYear });
    if (students.length === 0) {
      return res.status(404).json({ message: "No students found for the given criteria." });
    }

    // Store teacher's session
    ongoingAttendanceSessions.set(teacherId, {
      roomNo,
      students: new Set(students.map(s => s._id.toString())),
      responses: new Map(),
      startTime: new Date(),
      roomCoordinates: room.coordinates
    });

    // Emit event to start attendance
    req.io.emit("attendanceStarted", {
      roomNo,
      branch,
      admissionYear,
      students: students.map(student => student.email),
      coordinates: room.coordinates
    });

    res.status(200).json({
      message: "Attendance process started successfully.",
      sessionId: teacherId,
      students: students.map(student => ({
        email: student.email,
        status: 'Pending'
      }))
    });
  } catch (error) {
    console.error('Start attendance error:', error);
    res.status(500).json({ message: "Error starting attendance.", error: error.message });
  }
});

// Handle student coordinates
attendanceR.post("/send-coordinates", authenticate, async (req, res) => {
  const { roomNo, latitude, longitude } = req.body;
  const studentId = req.user.id;

  try {
    // Find active session for the room
    let session = null;
    for (const [teacherId, s] of ongoingAttendanceSessions.entries()) {
      if (s.roomNo === roomNo) {
        session = { teacherId, ...s };
        break;
      }
    }

    if (!session) {
      return res.status(400).json({ message: "No active attendance session found." });
    }

    // Verify student is part of the session
    if (!session.students.has(studentId)) {
      return res.status(403).json({ message: "Student not part of this session." });
    }

    // Convert coordinates to numbers and ensure they're valid
    const studentLat = Number(latitude);
    const studentLon = Number(longitude);

    if (isNaN(studentLat) || isNaN(studentLon)) {
      return res.status(400).json({ message: "Invalid coordinates provided." });
    }

    // Increased tolerance (approximately 20 meters)
    const TOLERANCE = 0.0002;

    // Create polygon points from room coordinates
    const polygonPoints = session.roomCoordinates.map(coord => ({
      latitude: Number(coord.latitude),
      longitude: Number(coord.longitude)
    }));

    // Add tolerance to create a buffer zone
    const expandedPolygon = polygonPoints.map(point => ({
      latitude: point.latitude + (Math.random() * 2 - 1) * TOLERANCE,
      longitude: point.longitude + (Math.random() * 2 - 1) * TOLERANCE
    }));

    // Check if student is within the polygon
    const studentPoint = {
      latitude: studentLat,
      longitude: studentLon
    };

    const isInside = isPointInPolygon(studentPoint, expandedPolygon);

    // Log detailed debugging information
    console.log('Attendance Check Details:', {
      studentPoint,
      expandedPolygon,
      isInside,
      tolerance: TOLERANCE,
      originalPolygon: polygonPoints
    });

    // Get student email
    const student = await studentModel.findById(studentId);
    if (!student) {
      return res.status(404).json({ message: "Student not found." });
    }

    // Update attendance status
    const status = isInside ? "Present" : "Absent";
    session.responses.set(studentId, {
      status,
      coordinates: { latitude: studentLat, longitude: studentLon },
      email: student.email
    });

    // Emit real-time update
    req.io.emit("attendanceUpdate", {
      studentId,
      email: student.email,
      status,
      coordinates: { latitude: studentLat, longitude: studentLon }
    });

    // Send response to student with detailed information
    res.status(200).json({ 
      message: "Attendance recorded.",
      status,
      isInside,
      details: {
        studentCoordinates: studentPoint,
        roomPolygon: polygonPoints,
        expandedPolygon,
        tolerance: TOLERANCE
      }
    });

    if (session.responses.size === session.students.size) {
      const finalAttendance = Array.from(session.responses.entries()).map(([id, data]) => ({
        studentId: id,
        email: data.email,
        status: data.status,
        coordinates: data.coordinates
      }));

      // Emit final results
      req.io.emit("finalAttendance", {
        attendance: finalAttendance
      });

      // Save to database
      const attendance = new attendanceModel({
        roomNo,
        teacherId: session.teacherId,
        students: finalAttendance,
        date: session.startTime
      });
      await attendance.save();

      // Clean up session
      ongoingAttendanceSessions.delete(session.teacherId);
    }
  } catch (error) {
    console.error('Send coordinates error:', error);
    res.status(500).json({ message: "Error processing attendance.", error: error.message });
  }
});
module.exports = { attendanceR };