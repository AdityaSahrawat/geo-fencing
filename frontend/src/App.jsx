import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Login from './components/login';
import StudentDashboard from './components/studentDashboard';
import TeacherDashboard from './components/teacherDashboard';
import { PrivateRoute } from './components/privateRoute';

function App() {
  return (
    <Router>
      <div className="min-h-screen bg-gray-100">
        <Routes>
          <Route path="/" element={<Login />} />
          <Route
            path="/student-dashboard"
            element={
              <PrivateRoute role="students">
                <StudentDashboard />
              </PrivateRoute>
            }
          />
          <Route
            path="/teacher-dashboard"
            element={
              <PrivateRoute role="teacher">
                <TeacherDashboard />
              </PrivateRoute>
            } 
          />
        </Routes>
      </div>
    </Router>
  );
}

export default App;