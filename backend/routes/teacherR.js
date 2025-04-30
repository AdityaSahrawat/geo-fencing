const express = require("express")
const jwt = require("jsonwebtoken")
const { teacherModel } = require("../mdb")

const teacherR = express.Router()

teacherR.post("/register", async (req, res) => {
  const { email, name, password, role } = req.body

  try {
    const existingTeacher = await teacherModel.findOne({ email })
    if (existingTeacher) {
      return res.status(400).json({ message: "Teacher already exists" })
    }

    const teacher = new teacherModel({
      email,
      name,
      password,
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
  console.log("req at login")

  try {
    console.log("1")
    const teacher = await teacherModel.findOne({ email })
    if (!teacher) {
      return res.status(400).json({ message: "Teacher not found" })
    }
    console.log("2")
    if(teacher.password != password){
      return res.status(400).json({ message: "Invalid credentials" })
    }
    console.log("3");
    const token = jwt.sign({ id: teacher._id }, process.env.JWT_SECRET)
    res.status(200).json({ message: "Teacher signed in successfully", token , teacher })
  } catch (error) {
    res.status(500).json({ message: "Error signing in teacher", error })
  }
})

module.exports = { teacherR }