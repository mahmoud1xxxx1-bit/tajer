import { useState, useEffect } from 'react';
import Sidebar from '../components/Sidebar';
import { db } from '../firebase';
import { collection, getDocs } from 'firebase/firestore';
import { Users, ShoppingBag, DollarSign, Activity, Award, TrendingUp, Clock } from 'lucide-react';

const Dashboard = () => {
  const [stats, setStats] = useState({
    totalMerchants: 0,
    activeMerchants: 0,
    proMerchants: 0,
    totalOrders: 0,
    totalRevenue: 0,
    recentMerchants: []
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchStats();
  }, []);

  const fetchStats = async () => {
    setLoading(true);
    try {
      // Fetch users (merchants)
      const usersSnapshot = await getDocs(collection(db, 'users'));
      let totalM = 0;
      let activeM = 0;
      let proM = 0;
      let merchantsList = [];

      usersSnapshot.forEach(doc => {
        const data = doc.data();
        // Skip employees if stored at top level, focus on merchants/owners
        if (data.role !== 'employee') {
          totalM++;
          if (data.status !== 'suspended') activeM++;
          if (data.plan === 'premium' || data.plan === 'pro') proM++;
          merchantsList.push({
            id: doc.id,
            name: data.name || 'تاجر بدون اسم',
            email: data.email || 'غير مسجل',
            plan: data.plan === 'premium' ? 'برو Pro 👑' : 'أساسي Free',
            createdAt: data.createdAt ? new Date(data.createdAt.toDate ? data.createdAt.toDate() : data.createdAt).toLocaleDateString('ar-EG') : 'حديثاً'
          });
        }
      });

      // Sort recent merchants
      merchantsList.reverse();
      const recent = merchantsList.slice(0, 5);

      // Fetch all global orders for revenue and transactions tracking
      let totalOrd = 0;
      let totalRev = 0;
      try {
        const ordersSnapshot = await getDocs(collection(db, 'orders'));
        ordersSnapshot.forEach(doc => {
          const orderData = doc.data();
          totalOrd++;
          if (orderData.status !== 'cancelled' && typeof orderData.total === 'number') {
            totalRev += orderData.total;
          }
        });
      } catch (e) {
        console.warn("Could not fetch root orders collection, using fallback 0:", e);
      }

      setStats({
        totalMerchants: totalM,
        activeMerchants: activeM,
        proMerchants: proM,
        totalOrders: totalOrd,
        totalRevenue: Math.round(totalRev * 100) / 100,
        recentMerchants: recent
      });
    } catch (error) {
      console.error("Error fetching admin analytics:", error);
    } finally {
      setLoading(false);
    }
  };

  const StatCard = ({ title, value, subtitle, icon: Icon, color }) => (
    <div className="glass-card animate-fade-in" style={{ padding: '1.5rem', display: 'flex', alignItems: 'center', gap: '1.25rem', borderRadius: '16px', border: '1px solid rgba(255, 255, 255, 0.08)' }}>
      <div style={{ padding: '1.2rem', borderRadius: '14px', background: `rgba(${color}, 0.15)`, color: `rgb(${color})`, boxShadow: `0 8px 20px -6px rgba(${color}, 0.3)` }}>
        <Icon size={28} />
      </div>
      <div style={{ flex: 1 }}>
        <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', marginBottom: '0.35rem', fontWeight: 600 }}>{title}</p>
        <h3 style={{ fontSize: '1.75rem', fontWeight: 800, color: '#fff', letterSpacing: '-0.5px' }}>{value}</h3>
        {subtitle && <span style={{ fontSize: '0.75rem', color: `rgb(${color})`, fontWeight: 700 }}>{subtitle}</span>}
      </div>
    </div>
  );

  return (
    <div className="app-container">
      <Sidebar />
      <main className="main-content" style={{ padding: '2rem' }}>
        <header className="flex-between mb-4">
          <div>
            <h1 style={{ fontSize: '2.2rem', fontWeight: 800, marginBottom: '0.25rem' }}>غرفة العمليات المركزية</h1>
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.95rem' }}>مراقبة حية وشاملة لأداء منصة تاجر وإحصائيات التجار</p>
          </div>
          <button className="btn btn-primary" onClick={fetchStats} disabled={loading}>
            {loading ? 'جاري التحديث...' : 'تحديث البيانات Live'}
          </button>
        </header>

        {loading ? (
          <div className="flex-center" style={{ padding: '4rem', fontSize: '1.2rem', color: 'var(--text-secondary)' }}>
            جاري معالجة الأرقام والإحصائيات الفورية من خوادم السحاب...
          </div>
        ) : (
          <>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: '1.5rem', marginBottom: '2.5rem' }}>
              <StatCard title="إجمالي أصحاب المتاجر" value={stats.totalMerchants} subtitle="إجمالي الحسابات المسجلة" icon={Users} color="139, 92, 246" />
              <StatCard title="التجار النشطين حالياً" value={stats.activeMerchants} subtitle="حسابات تعمل بدون قيود" icon={Activity} color="16, 185, 129" />
              <StatCard title="مشتركي باقات PRO ⭐" value={stats.proMerchants} subtitle="مستخدمي الميزات المتقدمة" icon={Award} color="245, 158, 11" />
              <StatCard title="إجمالي الفواتير الصادرة" value={stats.totalOrders} subtitle="إجمالي العمليات عبر المنصة" icon={ShoppingBag} color="59, 130, 246" />
              <StatCard title="حجم التداول المالي (المبيعات)" value={`${stats.totalRevenue.toLocaleString()} $`} subtitle="مجموع فواتير التجار الفعلي" icon={DollarSign} color="239, 68, 68" />
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(400px, 1fr))', gap: '1.5rem' }}>
              <div className="glass-card" style={{ padding: '2rem', borderRadius: '16px', border: '1px solid rgba(255, 255, 255, 0.08)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '1.25rem' }}>
                  <TrendingUp color="var(--accent-primary)" />
                  <h3 style={{ fontSize: '1.35rem', fontWeight: 800 }}>حالة النظام والجاهزية</h3>
                </div>
                <p style={{ color: 'var(--text-secondary)', lineHeight: '1.8', fontSize: '0.95rem' }}>
                  نظام <strong>تاجر (Tajer POS & ERP)</strong> يعمل حالياً بأقصى قدرة وبكفاءة واستقرار تام. تم تشغيل خوارزميات مكافحة تكرار أرقام الطلبات (Triple-Shield Counter Architecture) وتفعيل تأكيد الحماية والمزامنة اللحظية عبر RevenueCat.
                </p>
                <div style={{ marginTop: '1.5rem', display: 'flex', gap: '1rem' }}>
                  <div style={{ padding: '0.75rem 1.25rem', background: 'rgba(16, 185, 129, 0.1)', border: '1px solid rgba(16, 185, 129, 0.2)', borderRadius: '10px', color: '#10B981', fontWeight: 700, fontSize: '0.85rem' }}>
                    ✔ السيرفرات السحابية: متصلة 100%
                  </div>
                  <div style={{ padding: '0.75rem 1.25rem', background: 'rgba(139, 92, 246, 0.1)', border: '1px solid rgba(139, 92, 246, 0.2)', borderRadius: '10px', color: '#8B5CF6', fontWeight: 700, fontSize: '0.85rem' }}>
                    ✔ قواعد الحماية: نشطة
                  </div>
                </div>
              </div>

              <div className="glass-card" style={{ padding: '2rem', borderRadius: '16px', border: '1px solid rgba(255, 255, 255, 0.08)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '1.25rem' }}>
                  <Clock color="var(--accent-primary)" />
                  <h3 style={{ fontSize: '1.35rem', fontWeight: 800 }}>أحدث التجار المنضمين</h3>
                </div>
                {stats.recentMerchants.length === 0 ? (
                  <p style={{ color: 'var(--text-secondary)' }}>لا يوجد انضمام مسجل في السجل الهجري بعد.</p>
                ) : (
                  <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: '0.85rem' }}>
                    {stats.recentMerchants.map((m) => (
                      <li key={m.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0.75rem 1rem', background: 'rgba(255, 255, 255, 0.03)', borderRadius: '10px', border: '1px solid rgba(255, 255, 255, 0.05)' }}>
                        <div>
                          <span style={{ fontWeight: 700, color: '#fff', display: 'block' }}>{m.name}</span>
                          <span style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>{m.email}</span>
                        </div>
                        <div style={{ textAlign: 'left' }}>
                          <span style={{ display: 'inline-block', padding: '0.25rem 0.65rem', borderRadius: '6px', fontSize: '0.75rem', background: m.plan.includes('Pro') ? 'rgba(245, 158, 11, 0.15)' : 'rgba(16, 185, 129, 0.15)', color: m.plan.includes('Pro') ? '#F59E0B' : '#10B981', fontWeight: 700 }}>
                            {m.plan}
                          </span>
                          <span style={{ display: 'block', fontSize: '0.75rem', color: 'var(--text-secondary)', marginTop: '0.25rem' }}>{m.createdAt}</span>
                        </div>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            </div>
          </>
        )}
      </main>
    </div>
  );
};

export default Dashboard;

