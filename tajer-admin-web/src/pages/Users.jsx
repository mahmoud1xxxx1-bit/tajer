import { useState, useEffect } from 'react';
import Sidebar from '../components/Sidebar';
import { db } from '../firebase';
import { collection, getDocs, doc, updateDoc, deleteDoc } from 'firebase/firestore';
import { ShieldAlert, Trash2, Edit3, Power, PowerOff } from 'lucide-react';

const Users = () => {
  const [merchants, setMerchants] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchMerchants();
  }, []);

  const fetchMerchants = async () => {
    setLoading(true);
    try {
      const querySnapshot = await getDocs(collection(db, 'merchants'));
      const merchantsList = querySnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setMerchants(merchantsList);
    } catch (error) {
      console.error("Error fetching merchants:", error);
    } finally {
      setLoading(false);
    }
  };

  const toggleStatus = async (merchantId, currentStatus) => {
    try {
      const newStatus = currentStatus === 'active' ? 'suspended' : 'active';
      await updateDoc(doc(db, 'merchants', merchantId), {
        status: newStatus
      });
      setMerchants(merchants.map(m => m.id === merchantId ? { ...m, status: newStatus } : m));
    } catch (error) {
      alert('حدث خطأ أثناء تغيير الحالة');
    }
  };

  const deleteMerchant = async (merchantId) => {
    if (window.confirm('هل أنت متأكد من حذف هذا التاجر نهائياً؟ سيتم حذف جميع بياناته.')) {
      try {
        await deleteDoc(doc(db, 'merchants', merchantId));
        setMerchants(merchants.filter(m => m.id !== merchantId));
      } catch (error) {
        alert('حدث خطأ أثناء החذف');
      }
    }
  };

  return (
    <div className="app-container">
      <Sidebar />
      <main className="main-content">
        <header className="flex-between mb-4">
          <h1 style={{ fontSize: '2rem', fontWeight: 800 }}>إدارة التجار</h1>
          <button className="btn btn-secondary" onClick={fetchMerchants}>تحديث البيانات</button>
        </header>

        <div className="glass-panel" style={{ padding: '1.5rem', overflowX: 'auto' }}>
          {loading ? (
            <div className="flex-center" style={{ padding: '2rem' }}>جاري التحميل...</div>
          ) : merchants.length === 0 ? (
            <div className="flex-center" style={{ padding: '2rem', color: 'var(--text-secondary)' }}>لا يوجد تجار مسجلين بعد</div>
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th>اسم التاجر</th>
                  <th>البريد الإلكتروني</th>
                  <th>خطة الاشتراك</th>
                  <th>الحالة</th>
                  <th>تاريخ التسجيل</th>
                  <th>إجراءات</th>
                </tr>
              </thead>
              <tbody>
                {merchants.map((merchant) => (
                  <tr key={merchant.id} className="animate-fade-in">
                    <td style={{ fontWeight: 700 }}>{merchant.name || 'بدون اسم'}</td>
                    <td style={{ color: 'var(--text-secondary)' }} dir="ltr" align="right">{merchant.email}</td>
                    <td>
                      <span className={`badge ${merchant.plan === 'pro' ? 'badge-warning' : 'badge-success'}`}>
                        {merchant.plan === 'pro' ? 'برو' : 'مجاني'}
                      </span>
                    </td>
                    <td>
                      <span className={`badge ${merchant.status === 'active' ? 'badge-success' : 'badge-danger'}`}>
                        {merchant.status === 'active' ? 'نشط' : 'موقوف'}
                      </span>
                    </td>
                    <td style={{ color: 'var(--text-secondary)', fontSize: '0.875rem' }}>
                      {merchant.createdAt ? new Date(merchant.createdAt.toDate()).toLocaleDateString('ar-EG') : 'غير متوفر'}
                    </td>
                    <td>
                      <div className="flex-center gap-2" style={{ justifyContent: 'flex-start' }}>
                        <button 
                          title={merchant.status === 'active' ? 'إيقاف الحساب' : 'تفعيل الحساب'}
                          onClick={() => toggleStatus(merchant.id, merchant.status)}
                          style={{ background: 'none', border: 'none', cursor: 'pointer', color: merchant.status === 'active' ? 'var(--warning)' : 'var(--success)' }}
                        >
                          {merchant.status === 'active' ? <PowerOff size={18} /> : <Power size={18} />}
                        </button>
                        <button 
                          title="تعديل الاشتراك"
                          style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--accent-primary)' }}
                        >
                          <Edit3 size={18} />
                        </button>
                        <button 
                          title="حذف التاجر"
                          onClick={() => deleteMerchant(merchant.id)}
                          style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--danger)' }}
                        >
                          <Trash2 size={18} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </main>
    </div>
  );
};

export default Users;
