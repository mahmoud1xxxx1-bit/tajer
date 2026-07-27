import { useState, useEffect } from 'react';
import Sidebar from '../components/Sidebar';
import { db } from '../firebase';
import { collection, getDocs, query, orderBy } from 'firebase/firestore';
import { Users, ShoppingBag, DollarSign, Activity } from 'lucide-react';

const Dashboard = () => {
  const [stats, setStats] = useState({
    totalMerchants: 0,
    activeMerchants: 0,
    totalOrders: 0,
    totalRevenue: 0
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchStats();
  }, []);

  const fetchStats = async () => {
    try {
      const merchantsSnapshot = await getDocs(collection(db, 'merchants'));
      
      let totalM = 0;
      let activeM = 0;
      
      merchantsSnapshot.forEach(doc => {
        totalM++;
        if (doc.data().status === 'active') activeM++;
      });

      setStats({
        totalMerchants: totalM,
        activeMerchants: activeM,
        totalOrders: 0, // Would need order aggregation
        totalRevenue: 0 // Would need revenue aggregation
      });
    } catch (error) {
      console.error("Error fetching stats:", error);
    } finally {
      setLoading(false);
    }
  };

  const StatCard = ({ title, value, icon: Icon, color }) => (
    <div className="glass-card animate-fade-in" style={{ padding: '1.5rem', display: 'flex', alignItems: 'center', gap: '1rem' }}>
      <div style={{ padding: '1rem', borderRadius: '12px', background: `rgba(${color}, 0.1)`, color: `rgb(${color})` }}>
        <Icon size={24} />
      </div>
      <div>
        <p style={{ color: 'var(--text-secondary)', fontSize: '0.875rem', marginBottom: '0.25rem' }}>{title}</p>
        <h3 style={{ fontSize: '1.5rem', fontWeight: 700 }}>{value}</h3>
      </div>
    </div>
  );

  return (
    <div className="app-container">
      <Sidebar />
      <main className="main-content">
        <header className="flex-between mb-4">
          <h1 style={{ fontSize: '2rem', fontWeight: 800 }}>الرئيسية</h1>
        </header>

        {loading ? (
          <div>جاري التحميل...</div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '1.5rem' }}>
            <StatCard title="إجمالي التجار" value={stats.totalMerchants} icon={Users} color="139, 92, 246" />
            <StatCard title="التجار النشطين" value={stats.activeMerchants} icon={Activity} color="16, 185, 129" />
            <StatCard title="إجمالي الطلبات (قريباً)" value={stats.totalOrders} icon={ShoppingBag} color="245, 158, 11" />
            <StatCard title="الإيرادات (قريباً)" value={`${stats.totalRevenue} $`} icon={DollarSign} color="239, 68, 68" />
          </div>
        )}
        
        <div className="glass-card mt-4" style={{ padding: '2rem', minHeight: '300px' }}>
          <h3 className="mb-4 text-gradient">نظرة عامة على النظام</h3>
          <p style={{ color: 'var(--text-secondary)' }}>
            مرحباً بك في لوحة الإدارة العليا المستقلة لنظام تاجر. من خلال هذه اللوحة، يمكنك التحكم الكامل بجميع المشتركين والتجار بأمان وسرية تامة دون تواجد هذه الأدوات في تطبيق التجار.
          </p>
        </div>
      </main>
    </div>
  );
};

export default Dashboard;
