const express = require("express")
const jwt = require("jsonwebtoken")
const bcrypt = require("bcryptjs")
const geolib = require("geolib")
const { authenticate } = require("../middleware/auth")
const { teacherModel, attendanceModel, studentModel, roomModel } = require("../mdb")

const teacherR = express.Router()

teacherR.post("/register", async (req, res) => {
  const { email, name, password, role } = req.body

  try {
    const existingTeacher = await teacherModel.findOne({ email })
    if (existingTeacher) {
      return res.status(400).json({ message: "Teacher already exists" })
    }

    const hashedPassword = await bcrypt.hash(password, 10)
    const teacher = new teacherModel({
      email,
      name,
      password: hashedPassword,
      role
    })
    await teacher.save()

    const token = jwt.sign({ id: teacher._id }, process.env.JWT_SECRET)
    res.status(201).json({ message: "Teacher signed up successfully", token })
  } catch (error) {
    res.status(500).json({ message: "Error signing up teacher", error })
  }
})

teacherR.post("/login", async (req, res) => {
  const { email, password } = req.body

  try {
    const teacher = await teacherModel.findOne({ email })
    if (!teacher) {
      return res.status(400).json({ message: "Teacher not found" })
    }

    const isMatch = await bcrypt.compare(password, teacher.password)
    if (!isMatch) {
      return res.status(400).json({ message: "Invalid credentials" })
    }

    const token = jwt.sign({ id: teacher._id }, process.env.JWT_SECRET)
    res.status(200).json({ message: "Teacher signed in successfully", token })
  } catch (error) {
    res.status(500).json({ message: "Error signing in teacher", error })
  }
})

teacherR.get("/history", authenticate, async (req, res) => {
  const { teacherId } = req.query

  try {
    const attendanceHistory = await attendanceModel.find({ teacherId }).populate("students.studentId")
    res.status(200).json({ attendanceHistory })
  } catch (error) {
    res.status(500).json({ message: "Error fetching attendance history", error })
  }
})

teacherR.post("/takeattendance", authenticate, async (req, res) => {
  const { roomNo, branch, admissionYear } = req.body
  const teacherId = req.user.id

  try {
    const room = await roomModel.findOne({ roomNo })
    if (!room) {
      return res.status(404).json({ message: "Room not found" })
    }

    const students = await studentModel.find({ branch, admissionYear })

    const attendanceRecords = await Promise.all(
      students.map(async (student) => {
        const studentCoords = {
          latitude: 12.34, // Replace with actual coordinates from the frontend
          longitude: 56.78,
        }

        const isInside = geolib.isPointInPolygon(studentCoords, room.coordinates)

        return {
          studentId: student._id,
          status: isInside ? "Present" : "Absent",
        }
      })
    )

    const attendance = new attendanceModel({
      roomNo,
      branch,
      admissionYear,
      teacherId,
      students: attendanceRecords,
    })
    await attendance.save()

    res.status(201).json({ message: "Attendance recorded successfully", attendance })
  } catch (error) {
    res.status(500).json({ message: "Error recording attendance", error })
  }
})

module.exports = { teacherR }