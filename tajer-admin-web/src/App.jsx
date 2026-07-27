import { HashRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { useState, useEffect } from 'react';
import { auth } from './firebase';
import { onAuthStateChanged } from 'firebase/auth';

import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Users from './pages/Users';
import Plans from './pages/Plans';

function App() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const isSupport = localStorage.getItem('isSupport') === 'true';
    if (isSupport) {
      setUser({ uid: 'support', email: 'support@alldown.uk' });
      setLoading(false);
    }
    
    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      if (!isSupport) {
        setUser(currentUser);
      }
      setLoading(false);
    });
    return () => unsubscribe();
  }, []);

  if (loading) {
    return <div className="flex-center" style={{height: '100vh'}}>جاري التحميل...</div>;
  }

  return (
    <Router>
      <Routes>
        <Route path="/login" element={!user ? <Login /> : <Navigate to="/" />} />
        <Route path="/" element={user ? <Dashboard /> : <Navigate to="/login" />} />
        <Route path="/users" element={user ? <Users /> : <Navigate to="/login" />} />
        <Route path="/plans" element={user ? <Plans /> : <Navigate to="/login" />} />
      </Routes>
    </Router>
  );
}

export default App;
