





const geolib = require("geolib");
const {roomModel} = require("./mdb")

// Function to check if a point is inside a polygon
const isInsideRoom = (studentCoords, roomNo) => {

    const roomCoords = roomModel.findOne({roomNo})
    

  return geolib.isPointInPolygon(studentCoords, roomCoords);
};