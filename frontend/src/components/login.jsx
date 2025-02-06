import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';

function Login() {
  const [isLogin, setIsLogin] = useState(true);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [rollNo, setRollNo] = useState('');
  const [branch, setBranch] = useState('');
  const [admissionYear, setAdmissionYear] = useState('');
  const [role, setRole] = useState('students');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setIsLoading(true);

    try {
      const endpoint = isLogin ? 'login' : 'register';
      const data = isLogin
        ? { email, password, role }
        : role === 'students'
        ? { email, password, role, name, rollNo, branch, admissionYear }
        : { email, password, role, name };

      const response = await axios.post(
        `http://10.0.10.5:5000/api/${role}/${endpoint}`,
        data
      );

      localStorage.setItem('token', response.data.token);
      localStorage.setItem('role', role);

      navigate(role === 'students' ? '/student-dashboard' : '/teacher-dashboard');
    } catch (error) {
      console.error('Authentication error:', error);
      setError(
        isLogin
          ? 'Login failed. Please check your credentials.'
          : 'Registration failed. Please try again.'
      );
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-100">
      <div className="bg-white p-8 rounded-lg shadow-lg w-96">
        <h2 className="text-2xl font-bold mb-6 text-center">
          {isLogin ? 'Login' : 'Register'}
        </h2>
        {error && (
          <div className="mb-4 p-3 bg-red-50 text-red-600 rounded-lg text-center">
            {error}
          </div>
        )}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-gray-700 mb-2">College Email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full p-2 border rounded-lg focus:ring-2 focus:ring-blue-500"
              placeholder="e.g., 23bcs006@iiitdwd.ac.in"
              required
            />
          </div>
          <div>
            <label className="block text-gray-700 mb-2">Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full p-2 border rounded-lg focus:ring-2 focus:ring-blue-500"
              required
            />
          </div>
          {!isLogin && (
            <>
              <div>
                <label className="block text-gray-700 mb-2">Full Name</label>
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="w-full p-2 border rounded-lg focus:ring-2 focus:ring-blue-500"
                  required
                />
              </div>
              {role === 'students' && (
                <>
                  <div>
                    <label className="block text-gray-700 mb-2">Roll No</label>
                    <input
                      type="text"
                      value={rollNo}
                      onChange={(e) => setRollNo(e.target.value)}
                      className="w-full p-2 border rounded-lg focus:ring-2 focus:ring-blue-500"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-gray-700 mb-2">Branch</label>
                    <input
                      type="text"
                      value={branch}
                      onChange={(e) => setBranch(e.target.value)}
                      className="w-full p-2 border rounded-lg focus:ring-2 focus:ring-blue-500"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-gray-700 mb-2">
                      Admission Year
                    </label>
                    <input
                      type="text"
                      value={admissionYear}
                      onChange={(e) => setAdmissionYear(e.target.value)}
                      className="w-full p-2 border rounded-lg focus:ring-2 focus:ring-blue-500"
                      required
                    />
                  </div>
                </>
              )}
            </>
          )}
          <div>
            <label className="block text-gray-700 mb-2">Role</label>
            <select
              value={role}
              onChange={(e) => setRole(e.target.value)}
              className="w-full p-2 border rounded-lg focus:ring-2 focus:ring-blue-500"
            >
              <option value="students">Student</option>
              <option value="teacher">Teacher</option>
            </select>
          </div>
          <button
            type="submit"
            disabled={isLoading}
            className={`w-full p-3 rounded-lg text-white font-medium ${
              isLoading
                ? 'bg-blue-400 cursor-not-allowed'
                : 'bg-blue-600 hover:bg-blue-700'
            }`}
          >
            {isLoading
              ? 'Processing...'
              : isLogin
              ? 'Login'
              : 'Register'}
          </button>
          <button
            type="button"
            onClick={() => setIsLogin(!isLogin)}
            className="w-full text-blue-600 hover:text-blue-700"
          >
            {isLogin
              ? 'Need an account? Register'
              : 'Already have an account? Login'}
          </button>
        </form>
      </div>
    </div>
  );
}

export default Login;