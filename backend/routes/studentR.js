const express = require("express")
const {studentModel , verifiedEmailModel} = require("../mdb")
const bcrypt = require("bcryptjs")
const jwt = require("jsonwebtoken")
const crypto = require("crypto");
const nodemailer = require("nodemailer");

const studentR = express.Router()
// const verificationCodes = {};

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'geoattendanceiiitdwd@gmail.com',
    pass: 'fizk nptg lcsu xiqv',
  },
});

const parseEmail = (email) => {
  const emailRegex = /^(\d{2})(bcs|bds|bec)(\d{3})@iiitdwd.ac.in$/;
  const match = email.match(emailRegex);

  if (!match) return null;

  const year = `20${match[1]}`;
  const branchMap = { bcs: "CSE", bds: "DSAI", bec: "EC" };
  const branch = branchMap[match[2]];
  const rollNumber = match[3];

  return { year, branch, rollNumber };
};

studentR.post("/verify-email", async (req, res) => {
  const { email, code } = req.body;


  try{
    const storedData = await verifiedEmailModel.findOne({email : email})
    if (!storedData) return res.status(400).json({ message: "No verification request found" });
    console.log(storedData)
    console.log(storedData.code)
    console.log(code)
    if (Date.now() > storedData.expiresAt) {
      await verifiedEmailModel.deleteOne({email : email})
      return res.status(400).json({ message: "Verification code expired" });
    }

    if (storedData.code != code){
      return res.status(400).json({ message: "Invalid code" });
    } 

  }catch(e){
    res.status(500).json({
      message : "this email is in verification process"
    })
  }
  
  
  res.status(200).json({ message: "Email verified successfully. You can now register." });
});

studentR.post("/send-verification", async (req, res) => {
  const { email } = req.body;

  const parsedData = parseEmail(email);
  if (!parsedData) return res.status(400).json({ message: "Invalid email format" });

  const existingUser = await studentModel.findOne({ email });
  if (existingUser) return res.status(400).json({ message: "Email already registered" });

  const verificationCode = crypto.randomInt(100000, 999999);
  await verifiedEmailModel.findOneAndUpdate(
    { email }, // Find email in DB
    {
      code: verificationCode,
      expiresAt: new Date(Date.now() + 10 * 60 * 1000), // 10 minutes expiry
    },
    { upsert: true, new: true } // If not found, create new
  );

  const mailOptions = {
    from: "geoattendanceiiitdwd@gmail.com",
    to: email,
    subject: "Verify Your Email",
    text: `Your verification code is ${verificationCode}. This code expires in 10 minutes.`,
  };

  transporter.sendMail(mailOptions, (err) => {
    if (err) return res.status(500).json({ message: "Failed to send email" });
    res.status(200).json({ message: "Verification code sent to email" });
  });
});
 
studentR.post('/login', async (req, res) => {
  const { email, password, role } = req.body

  try {
    const student = await studentModel.findOne({ email })
    if (!student) {
      return res.status(400).json({ message: "student not found." })
    }

    if (password !== student.password) {
      console.log("Password does not match");
      return res.status(400).json({ message: "Invalid credentials." });
    }
    const userDetails = {
      name : student.name,
      rollNo : student.rollNo,
      branch : student.branch,
      admissionYear : student.admissionYear
    }
    console.log(userDetails)
    console.log(role)
    const token = jwt.sign({ id: student._id, role }, process.env.JWT_SECRET)
    console.log(userDetails)
    res.status(200).json({ token, role , userDetails })
  } catch (error) {
    res.status(500).json({ message: "Error logging in.", error })
  }
})

studentR.post("/register", async (req, res) => {
  const { email, name, password} = req.body;

  const vemail = await verifiedEmailModel.findOne({email: email}) 
  if (!vemail) return res.status(400).json({ message: "Email not verified" });

  // ✅ Extract Details from Email
  const parsedData = parseEmail(email);

  // ✅ Create User in Database
  const user = new studentModel({
    email,
    name,
    password,
    admissionYear: parsedData.year,
    branch: parsedData.branch,
    rollNo: parsedData.rollNumber,
    isVerified: true, // Mark as verified
  });

  await user.save();
  await verifiedEmailModel.deleteOne({email : email})
  res.status(201).json({ message: "Registration successful. You can now log in." });
});



module.exports = { studentR }