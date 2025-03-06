const express = require("express")
const {studentModel} = require("../mdb")
const bcrypt = require("bcryptjs")
const jwt = require("jsonwebtoken")
const { authenticate } = require("../middleware/auth")

const studentR = express.Router()
 
studentR.post('/login', async (req, res) => {
  const { email, password, role } = req.body

  try {
    const student = await studentModel.findOne({ email })
    if (!student) {
      return res.status(400).json({ message: "User not found." })
    }

    const isMatch = await bcrypt.compare(password, student.password)
    if (!isMatch) {
      consile.log("in match")
      return res.status(400).json({ message: "Invalid credentials." })
      
    }
    
    const token = jwt.sign({ id: student._id, role }, process.env.JWT_SECRET)
    console.log(token)
    res.status(200).json({ token, role })
  } catch (error) {
    res.status(500).json({ message: "Error logging in.", error })
  }
})

studentR.post('/register', async (req, res) => {
  const { email, password, role, name, rollNo, branch, admissionYear } = req.body

  try {
    const existingUser = await studentModel.findOne({ email })
    if (existingUser) {
      return res.status(400).json({ message: "User already exists." })
    }

    const hashedPassword = await bcrypt.hash(password, 10)
    const student = new studentModel({
      email,
      name,
      password: hashedPassword,
      role,
      rollNo,
      branch,
      admissionYear
    })
    await student.save()

    res.status(201).json({ message: "User registered successfully." })
  } catch (error) {
    res.status(500).json({ message: "Error registering user.", error })
  }
})



module.exports = { studentR }