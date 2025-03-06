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

module.exports = { teacherR }