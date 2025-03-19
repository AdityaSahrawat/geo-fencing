
const {Router} = require("express")
const jwt  = require ("jsonwebtoken")
const mongoose = require("mongoose")
const {attendanceModel, teacherModel} = require("../mdb")
const {roomModel} = require("../mdb")
const { authenticate } = require("../middleware/auth")


const notifR = Router();


notifR.post("/", async (req, res) => {
    const { roomNo, message } = req.body;
  
    try {
      console.log(`Notification for Room ${roomNo}: ${message}`);
      res.status(200).json({ message: "Notification sent successfully" });
    } catch (error) {
      res.status(500).json({ message: "Error sending notification", error });
    }
  });

  notifR.post("/addroom" , async(req , res)=>{
    const { roomNo, coordinates } = req.body;

  try {
    // Check if the room already exists
    const existingRoom = await roomModel.findOne({ roomNo });
    if (existingRoom) {
      return res.status(400).json({ message: "Room already exists." });
    }

    // Validate coordinates
    if (!coordinates || coordinates.length !== 4) {
      return res.status(400).json({ message: "Room must have exactly 4 coordinates." });
    }

    // Create a new room
    const room = new roomModel({ roomNo, coordinates });
    await room.save();

    res.status(201).json({ message: "Room added successfully.", room });
  } catch (error) {
    res.status(500).json({ message: "Error adding room.", error });
  }
  })


  notifR.post('/checkUser', authenticate, async (req, res) => {
    const userId = req.user.id;
    const role = req.user.role
    try {
      if(role == "student"){
        const user = await studentModel.findById(userId);
        if (!user) {
          return res.status(404).json({ message: "User not found" });
        }
    
        res.status(200).json({
          email: user.email,
          name: user.name,
          rollNo: user.rollNo,
          admissionYear: user.admissionYear,
          branch: user.branch
        });
      }else{
        const user = await teacherModel.findById(userId);
        if (!user) {
          return res.status(404).json({ message: "User not found" });
        }
    
        res.status(200).json({
          email: user.email,
          name: user.name
        });
      }
  
      
    } catch (e) {
      console.error("Error fetching user:", e);
      res.status(500).json({ message: "Internal server error" });
    }
  });


  module.exports= {notifR}