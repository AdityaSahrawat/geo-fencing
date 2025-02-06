const express = require("express")
const mongoose = require("mongoose")
const cors = require("cors")
const http = require("http")
const socketIo = require("socket.io")
const dotenv = require("dotenv")
dotenv.config()

const app = express()
const server = http.createServer(app)
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
    allowedHeaders: ["Content-Type"],
    credentials: true
  },
  allowEIO3: true // Ensures older clients can connect
});

app.use(cors())
app.use(express.json())
app.use((req, res, next) => {
  req.io = io
  next()
})

const {studentR} = require("./routes/studentR.js")
const {notifR} = require("./routes/notificationR.js")
const {attendanceR} = require("./routes/attendance.js")
const {teacherR} = require("./routes/teacherR.js")

app.use("/api/students", studentR)
app.use("/api/notify", notifR)
app.use("/api/attendance", attendanceR) 
app.use("/api/teacher", teacherR)

io.on("connection", (socket) => {
  console.log("A student connected:", socket.id)

  socket.on("joinRoom", (studentId) => {
    socket.join(studentId);
    console.log(`Student ${studentId} joined their attendance room`);
  });

  socket.on("disconnect", () => {
    console.log("A student disconnected:", socket.id)
  })
})

mongoose.connect(process.env.MONGODB_URI)
  .then(() => console.log('Connected to MongoDB'))
  .catch((err) => console.error('MongoDB connection error:', err))

const PORT = process.env.PORT || 5000
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`)
})