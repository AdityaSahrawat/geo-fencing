const jwt = require("jsonwebtoken");

// Authenticate user
const authenticate = (req, res, next) => {
  const token = req.header("Authorization")?.replace("Bearer ", "");
  if (!token) {
    return res.status(401).json({ message: "Access denied. No token provided." });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; // Attach user details to the request
    next();
  } catch (error) {
    res.status(400).json({ message: "Invalid token." });
  }
};

// // Authorize based on role
// const authorize = (role) => (req, res, next) => {
//   if (req.user.role !== role) {
//     return res.status(403).json({ message: "Access denied. Unauthorized role." });
//   }
//   next();
// };

module.exports = { authenticate };