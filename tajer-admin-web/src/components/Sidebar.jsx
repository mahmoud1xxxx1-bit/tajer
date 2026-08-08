import { Link, useLocation } from 'react-router-dom';
import { LayoutDashboard, Users, CreditCard, LogOut, ShieldCheck, Bell } from 'lucide-react';
import { auth } from '../firebase';
import { signOut } from 'firebase/auth';

const Sidebar = () => {
  const location = useLocation();

  const handleLogout = () => {
    signOut(auth);
    window.location.reload();
  };

  const navItems = [
    { path: '/', label: 'الرئيسية', icon: LayoutDashboard },
    { path: '/users', label: 'إدارة التجار', icon: Users },
    { path: '/plans', label: 'خطط الأسعار', icon: CreditCard },
    { path: '/notifications', label: 'الإشعارات', icon: Bell },
  ];

  return (
    <div className="sidebar glass-panel" style={{ borderRadius: '0', borderLeft: 'none', borderRight: '1px solid var(--border-color)' }}>
      <div className="flex-center mb-4 gap-2" style={{ paddingBottom: '2rem', borderBottom: '1px solid var(--border-color)' }}>
        <ShieldCheck size={32} color="var(--accent-primary)" />
        <h2 className="text-gradient" style={{ fontSize: '1.5rem', fontWeight: 800 }}>Tajer Admin</h2>
      </div>

      <nav style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
        {navItems.map((item) => {
          const isActive = location.pathname === item.path;
          const Icon = item.icon;
          return (
            <Link
              key={item.path}
              to={item.path}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.75rem',
                padding: '0.75rem 1rem',
                borderRadius: '8px',
                color: isActive ? '#fff' : 'var(--text-secondary)',
                background: isActive ? 'linear-gradient(135deg, var(--accent-primary), var(--accent-secondary))' : 'transparent',
                textDecoration: 'none',
                fontWeight: isActive ? 700 : 500,
                transition: 'all 0.3s ease'
              }}
            >
              <Icon size={20} />
              {item.label}
            </Link>
          );
        })}
      </nav>

      <button onClick={handleLogout} className="btn btn-danger w-full mt-4" style={{ gap: '0.5rem' }}>
        <LogOut size={20} />
        تسجيل الخروج
      </button>
    </div>
  );
};

export default Sidebar;
