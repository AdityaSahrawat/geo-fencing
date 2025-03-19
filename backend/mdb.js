const mongoose = require("mongoose")

const studentSchema = new mongoose.Schema({
  email:          { type: String, required: true, unique: true },
  password:       {type : String, required: true },
  name:           { type: String, required: true },
  rollNo:         { type: String, required: true },
  branch:         { type: String, required: true },
  admissionYear:  { type: String, required: true },
  isVerified : {type : Boolean , default : false , required : true}
});

const attendanceSchema = new mongoose.Schema({
  roomNo: { type: String, required: true },
  teacherId: { type: mongoose.Schema.Types.ObjectId, ref: "Teacher", required: true },
  date: { type: String, required: true },
  sessions: [
    {
      startTime: { type: Date, required: true },
      branch : {type : String , required: true} ,
      type: { type: String, enum: ["tutorial", "class", "lab"], required: true }, 
      students: [
        {
          studentId: { type: mongoose.Schema.Types.ObjectId, ref: "Student" },
          presentCount: { type: Number, default: 0 },
          absentCount: { type: Number, default: 0 },
          finalStatus: { type: String, enum: ["Present", "Absent"], default: "Absent" } // New field
        }
      ]
    }
  ]
}, { timestamps: true });

const verifiedEmailSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true },
  expiresAt: { type : Date },
  code : {type : String}
});




const teacherSchema = new mongoose.Schema({
  email:      { type: String, required: true, unique: true },
  name:       { type: String, required: true },
  password :  {type: String, required:true},
  role :      {type: String, required:true}
});

const roomSchema = new mongoose.Schema({
  roomNo: { type: String, required: true, unique: true },
  coordinates: {
    type: [
      {
        latitude: { type: Number, required: true },
        longitude: { type: Number, required: true },
      },
    ],
    required: true,
    validate: {
      validator: (coords) => coords.length === 4,
      message: "Room must have exactly 4 coordinates.",
    },
  },
});
  
const teacherModel = mongoose.model('teacherSchema', teacherSchema);
const studentModel = mongoose.model('studentSchema', studentSchema);
const attendanceModel = mongoose.model('attendanceSchema', attendanceSchema);
const roomModel = mongoose.model("roomSchema" ,roomSchema);
const verifiedEmailModel = mongoose.model("verificationSchema" , verifiedEmailSchema);

module.exports = {
  teacherModel,
    studentModel,
    attendanceModel,
    roomModel,
    verifiedEmailModel
}