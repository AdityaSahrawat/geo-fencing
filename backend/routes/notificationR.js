
const {Router} = require("express")
const jwt  = require ("jsonwebtoken")
const mongoose = require("mongoose")
const {attendanceModel} = require("../mdb")
const {roomModel} = require("../mdb")

const notifR = Router();




notifR.post("/", async (req, res) => {
    const { roomNo, message } = req.body;
  
    try {
      // Here, you can integrate with a real-time notification service (e.g., WebSocket, Firebase)
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

  module.exports= {notifR}