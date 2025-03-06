const express = require("express");
const { attendanceModel, roomModel, studentModel } = require("../mdb");
const { authenticate } = require("../middleware/auth");
const { isPointInPolygon } = require("geolib");
 // active
const attendanceR = express.Router();


global.responseTracker = new Map(); // Stores student responses temporarily
const ongoingAttendanceSessions = new Map();

// Start attendance session
attendanceR.post("/start", authenticate, async (req, res) => {
  try {
    const { roomNo, branch, admissionYear, type } = req.body;
    const teacherId = req.user.id;
    const today = new Date().toISOString().split("T")[0];

    const room = await roomModel.findOne({ roomNo });
    if (!room) return res.status(404).json({ message: "Room not found." });

    const students = await studentModel.find({ branch, admissionYear });
    if (!students.length) return res.status(404).json({ message: "No students found." });

    const newSession = {
      startTime: new Date(),
      type,
      students: students.map(student => ({
        studentId: student._id,
        email: student.email, // Include email for easy reference
        presentCount: 0,
        absentCount: 0,
        finalStatus: "Absent", // Initialize status as "Pending"
      })),
      roomNo,
      roomCoordinates: room.coordinates,
      responses: new Map(),
    };

    let attendance = await attendanceModel.findOne({ teacherId, roomNo, date: today });
    if (attendance) {
      attendance.sessions.push(newSession);
      await attendance.save();
    } else {
      attendance = new attendanceModel({
        roomNo,
        teacherId,
        date: today,
        sessions: [newSession],
      });
      await attendance.save();
    }

    ongoingAttendanceSessions.set(teacherId, newSession);

    // Emit the attendanceStarted event
    req.io.emit("attendanceStarted", {
      roomNo,
      students: students.map(s => s.email),
      roomCoordinates: room.coordinates,
    });

    res.status(200).json({ message: "New attendance session started.", students: newSession.students });
  } catch (error) {
    console.error("❌ Error starting attendance:", error);
    res.status(500).json({ message: "Error starting attendance.", error: error.message });
  }
});


// Student sends location
attendanceR.post("/send-coordinates", authenticate, async (req, res) => {
  const { roomNo, latitude, longitude } = req.body;
  const studentId = req.user.id;
  console.log("req came at /send coord")
  try {
    let session = null;
    for (const [teacherId, s] of ongoingAttendanceSessions.entries()) {
      if (s.roomNo === roomNo) {
        session = { teacherId, ...s };
        break;
      }
    }

    if (!session) {
      return res.status(400).json({ message: "No active attendance session." });
    }

    const isStudentInSession = session.students.some(student => 
      student.studentId.toString() === studentId
    );

    if (!isStudentInSession) {
      return res.status(403).json({ message: "Not part of session." });
    }

    const studentLat = Number(latitude), studentLon = Number(longitude);
    if (isNaN(studentLat) || isNaN(studentLon)) {
      return res.status(400).json({ message: "Invalid coordinates." });
    }

    const polygonPoints = session.roomCoordinates.map(coord => ({
      latitude: Number(coord.latitude),
      longitude: Number(coord.longitude)
    }));

    const isInside = isPointInPolygon({ latitude: studentLat, longitude: studentLon }, polygonPoints);
    const student = await studentModel.findById(studentId);
    if (!student) {
      return res.status(404).json({ message: "Student not found." });
    }

    const status = isInside ? "Present" : "Absent";
    
    global.responseTracker.set(studentId, { status, email: student.email });

    let attendance = await attendanceModel.findOne({ teacherId: session.teacherId, roomNo, date: new Date().toISOString().split("T")[0] });
    if (!attendance) {
      return res.status(404).json({ message: "Attendance session not found." });
    }
    const latestSession = attendance.sessions[attendance.sessions.length - 1];
    const studentInSession = latestSession.students.find(s => s.studentId.toString() === studentId);
    if (studentInSession) {
      if (status === "Present") {
        studentInSession.presentCount += 1;
      } else {
        studentInSession.absentCount += 1;
      }
    }
    await attendance.save();

    session.responses.set(studentId, { status, email: student.email });

    console.log("Emitting attendanceUpdate with data in /send coords:", {
      roomNo,
      students: session.students.map(student => ({
        studentId: student.studentId,
        email: student.email,
        status: student.finalStatus,
      }))
    })
    req.io.emit("attendanceUpdate", {
      roomNo,
      students: session.students.map(student => ({
        studentId: student.studentId,
        email: student.email,
        status: session.responses.get(student.studentId.toString())?.status || "Pending",
      }))
    });

    res.status(200).json({ message: "Attendance recorded.", status });
  } catch (error) {
    console.error("❌ Error processing attendance:", error);
    res.status(500).json({ message: "Error processing attendance.", error: error.message });
  }
});

attendanceR.post("/take", authenticate, async (req, res) => {
  const { roomNo } = req.body;
  const teacherId = req.user.id;
  const today = new Date().toISOString().split("T")[0];
  console.log("req came at /take")
  try {
    // Find the attendance record for the session
    let attendance = await attendanceModel.findOne({ teacherId, roomNo, date: today });
    if (!attendance) return res.status(400).json({ message: "No active session found." });

    // Get the latest session
    const latestSession = attendance.sessions[attendance.sessions.length - 1];
    

    if (!global.responseTracker) {
      global.responseTracker = new Map();
    }

    const studentIds = latestSession.students.map(s => s.studentId.toString());
    const studentsData = await studentModel.find({ _id: { $in: studentIds } }, "email");
    const studentEmailMap = new Map();

    studentsData.forEach(student => {
      studentEmailMap.set(student._id.toString(), student.email);
    });

    for (const student of latestSession.students) {
      const studentId = student.studentId.toString();
      const studentEmail = studentEmailMap.get(studentId) || "unknown@example.com"; // Get email from Map

      if (!global.responseTracker.has(studentId)) {
        student.absentCount += 1; // Increase absent count
        global.responseTracker.set(studentId, { status: "Absent", email: studentEmail });

        console.log(`✅ Marked student ${studentEmailMap.get(student.studentId.toString())} as absent.`);
      }
    }

    await attendance.save();


    console.log("📢 Emitting 'attendanceUpdate' with Pending statuses...");
    req.io.emit("attendanceUpdate", {
      roomNo,
      students: latestSession.students.map(student => ({
        studentId: student.studentId.toString(),
        email: studentEmailMap.get(student.studentId.toString()) || "unknown@example.com",
        status: "Pending" // UI only, doesn't affect database
      }))
    });
    global.responseTracker.clear();

    console.log("📢 Emitting 'requestCoordinates' event...");
    req.io.emit("requestCoordinates", {
      roomNo,
      students: latestSession.students.map(student => studentEmailMap.get(student.studentId.toString()))
    });

    res.status(200).json({ message: "Attendance updated successfully.", attendance: latestSession });

  } catch (error) {
    res.status(500).json({ message: "Error updating attendance.", error: error.message });
  }
});


// ✅ Stop attendance (Final save)
attendanceR.post("/stop", authenticate, async (req, res) => {
  const { roomNo } = req.body;
  const teacherId = req.user.id;
  const today = new Date().toISOString().split("T")[0];

  try {
    const attendance = await attendanceModel.findOne({ teacherId, roomNo, date: today });
    if (!attendance) return res.status(404).json({ message: "No records found." });

    const latestSession = attendance.sessions[attendance.sessions.length - 1];

    // Calculate finalStatus for each student
    latestSession.students.forEach(student => {
      student.finalStatus = student.presentCount > student.absentCount ? "Present" : "Absent";
    });

    await attendance.save();

    req.io.emit("finalAttendance", {
      roomNo,
      students: latestSession.students.map(student => ({
        email: student.email,
        finalStatus: student.finalStatus
      }))
    });
    res.status(200).json({ message: "Final attendance saved.", attendance });

    ongoingAttendanceSessions.delete(teacherId);

  } catch (error) {
    res.status(500).json({ message: "Error stopping attendance.", error: error.message });
  }
});

// filter history
attendanceR.get("/history", authenticate, async (req, res) => {
  const { teacherId, roomNo, date, branch, admissionYear, type } = req.query;
  console.log("req came at history")
  try {
    let filter = {};
    if (teacherId) filter.teacherId = teacherId;
    if (roomNo) filter.roomNo = roomNo;
    if (date) filter.date = date;
    if (branch) filter.branch = branch;
    if (admissionYear) filter.admissionYear = admissionYear;
    if (type) filter["sessions.type"] = type;

    const attendanceHistory = await attendanceModel.find(filter).sort({ date: -1 });

    if (!attendanceHistory.length) {
      return res.status(404).json({ message: "No attendance records found." });
    }

    res.status(200).json({ attendanceHistory });
  } catch (error) {
    res.status(500).json({ message: "Error fetching attendance history.", error: error.message });
  }
});

// Cancel class and mark all students as present
attendanceR.post("/cancel", authenticate, async (req, res) => {
  const { branch, admissionYear, type } = req.body;
  const teacherId = req.user.id;
  const today = new Date().toISOString().split("T")[0];

  try {
    // Find all students for the given branch and admission year
    const students = await studentModel.find({ branch, admissionYear });
    if (!students.length) {
      return res.status(404).json({ message: "No students found for the given criteria." });
    }

    // Create a new attendance record for the canceled class
    const newSession = {
      startTime: new Date(),
      type,
      students: students.map(student => ({
        studentId: student._id,
        presentCount: 1, // Mark all students as present
        absentCount: 0,
        finalStatus: "Present" // Set final status to Present
      })),
      roomNo: "N/A", // No room number since it's not related to a specific room
      roomCoordinates: [], // No coordinates needed
      responses: new Map() // No responses needed
    };

    // Save the new attendance record
    const attendance = new attendanceModel({
      roomNo: "N/A",
      teacherId,
      date: today,
      sessions: [newSession]
    });
    await attendance.save();

    res.status(200).json({ message: "Class canceled. All students marked as present.", attendance });

  } catch (error) {
    console.error("❌ Error canceling class:", error);
    res.status(500).json({ message: "Error canceling class.", error: error.message });
  }
});

attendanceR.post("/update-status", authenticate, async (req, res) => {
  const { sessionId, studentId, status } = req.body;

  try {
    const attendance = await attendanceModel.findOne({ "sessions._id": sessionId });
    if (!attendance) {
      return res.status(404).json({ message: "Session not found." });
    }

    const session = attendance.sessions.id(sessionId);
    if (!session) {
      return res.status(404).json({ message: "Session not found." });
    }

    const student = session.students.id(studentId);
    if (!student) {
      return res.status(404).json({ message: "Student not found." });
    }

    student.finalStatus = status;
    await attendance.save();

    res.status(200).json({ message: "Student status updated successfully." });
  } catch (error) {
    console.error("❌ Error updating student status:", error);
    res.status(500).json({ message: "Error updating student status.", error: error.message });
  }
});

attendanceR.post("/check" , async(req , res)=>{
  const { roomNo, latitude, longitude } = req.body;
  console.log("req 1")
  try {

    const room = await roomModel.findOne({ roomNo });
    console.log(room)
    if (!room) return res.status(404).json({ message: "Room not found." });

    const studentLat = Number(latitude), studentLon = Number(longitude);
    if (isNaN(studentLat) || isNaN(studentLon)) {
      return res.status(400).json({ message: "Invalid coordinates." });
    }
    
    const polygonPoints = room.coordinates.map(coord => ({
      latitude: Number(coord.latitude),
      longitude: Number(coord.longitude)
    }));
    polygonPoints.push(polygonPoints[0]); 
    console.log("Student Coordinates:", { latitude: studentLat, longitude: studentLon });
    console.log("Room Polygon Coordinates:", polygonPoints);

    const isInside = isPointInPolygon({ latitude: latitude, longitude: longitude }, polygonPoints);
    console.log("Is Inside?", isInside);

    const status = isInside ? "Present" : "Absent";

    res.json({
      status : status
    })
  }catch(e){
    res.json({
      message : "error is getting status"
    })
  }
})


module.exports = { attendanceR };
