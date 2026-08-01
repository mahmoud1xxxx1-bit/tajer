import { useState, useEffect } from 'react';
import Sidebar from '../components/Sidebar';
import { db } from '../firebase';
import { collection, getDocs, doc, updateDoc, deleteDoc, query, where } from 'firebase/firestore';
import { Eye, Trash2, Power, PowerOff, Award, Download, X, Users as UsersIcon, ShoppingBag, DollarSign, CheckCircle } from 'lucide-react';

const Users = () => {
  const [merchants, setMerchants] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedMerchant, setSelectedMerchant] = useState(null);
  const [merchantStaff, setMerchantStaff] = useState([]);
  const [merchantSales, setMerchantSales] = useState({ ordersCount: 0, totalRevenue: 0 });
  const [loadingDetails, setLoadingDetails] = useState(false);

  useEffect(() => {
    fetchMerchants();
  }, []);

  const fetchMerchants = async () => {
    setLoading(true);
    try {
      // Connect directly to the correct 'users' table in Firestore
      const querySnapshot = await getDocs(collection(db, 'users'));
      const merchantsList = [];
      querySnapshot.docs.forEach(doc => {
        const data = doc.data();
        // Focus on merchants/store accounts
        if (data.role !== 'employee') {
          merchantsList.push({
            id: doc.id,
            name: data.name || 'تاجر بدون اسم',
            email: data.email || 'غير متوفر',
            phone: data.phone || 'غير مسجل',
            plan: (data.plan === 'premium' || data.plan === 'pro') ? 'pro' : 'free',
            status: data.status === 'suspended' ? 'suspended' : 'active',
            createdAt: data.createdAt ? new Date(data.createdAt.toDate ? data.createdAt.toDate() : data.createdAt) : new Date()
          });
        }
      });
      // Sort newest first
      merchantsList.sort((a, b) => b.createdAt - a.createdAt);
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
      await updateDoc(doc(db, 'users', merchantId), {
        status: newStatus
      });
      setMerchants(merchants.map(m => m.id === merchantId ? { ...m, status: newStatus } : m));
      if (selectedMerchant && selectedMerchant.id === merchantId) {
        setSelectedMerchant({ ...selectedMerchant, status: newStatus });
      }
    } catch (error) {
      alert('حدث خطأ أثناء تغيير حالة التاجر.');
    }
  };

  const toggleProSubscription = async (merchant) => {
    try {
      const newPlan = merchant.plan === 'pro' ? 'merchant' : 'premium';
      await updateDoc(doc(db, 'users', merchant.id), {
        plan: newPlan
      });
      const updatedPlanStatus = newPlan === 'premium' ? 'pro' : 'free';
      setMerchants(merchants.map(m => m.id === merchant.id ? { ...m, plan: updatedPlanStatus } : m));
      if (selectedMerchant && selectedMerchant.id === merchant.id) {
        setSelectedMerchant({ ...selectedMerchant, plan: updatedPlanStatus });
      }
      alert(`تم تعديل باقة التاجر بنجاح إلى: ${updatedPlanStatus === 'pro' ? 'برو Pro 👑' : 'المجانية Free'}`);
    } catch (error) {
      alert('حدث خطأ أثناء تغيير الباقة الاستثنائية للتاجر.');
    }
  };

  const deleteMerchant = async (merchantId) => {
    if (window.confirm('هل أنت متأكد من حذف هذا التاجر نهائياً؟ سيتم إلغاء حسابه من المنصة.')) {
      try {
        await deleteDoc(doc(db, 'users', merchantId));
        setMerchants(merchants.filter(m => m.id !== merchantId));
        if (selectedMerchant && selectedMerchant.id === merchantId) setSelectedMerchant(null);
      } catch (error) {
        alert('حدث خطأ أثناء حذف الحساب.');
      }
    }
  };

  const openDetailsModal = async (merchant) => {
    setSelectedMerchant(merchant);
    setLoadingDetails(true);
    setMerchantStaff([]);
    setMerchantSales({ ordersCount: 0, totalRevenue: 0 });

    try {
      // 1. Fetch employees under users/{id}/employees
      const staffSnap = await getDocs(collection(db, 'users', merchant.id, 'employees'));
      const staffList = staffSnap.docs.map(d => ({ id: d.id, ...d.data() }));
      setMerchantStaff(staffList);

      // 2. Fetch total sales and orders for this merchant from root 'orders'
      const ordersSnap = await getDocs(query(collection(db, 'orders'), where('merchantId', '==', merchant.id)));
      let ordCount = 0;
      let revTotal = 0;
      ordersSnap.forEach(d => {
        const oData = d.data();
        ordCount++;
        if (oData.status !== 'cancelled' && typeof oData.total === 'number') {
          revTotal += oData.total;
        }
      });
      setMerchantSales({ ordersCount: ordCount, totalRevenue: Math.round(revTotal * 100) / 100 });
    } catch (err) {
      console.error("Error loading merchant deep details:", err);
    } finally {
      setLoadingDetails(false);
    }
  };

  const exportCSV = () => {
    if (merchants.length === 0) {
      alert('لا توجد بيانات متاحة للتصدير حالياً');
      return;
    }
    const headers = ['اسم التاجر', 'البريد الإلكتروني', 'رقم الهاتف', 'الخطة', 'حالة الحساب', 'تاريخ الانضمام'];
    const rows = merchants.map(m => [
      `"${m.name}"`,
      `"${m.email}"`,
      `"${m.phone}"`,
      `"${m.plan === 'pro' ? 'برو Pro' : 'مجاني Free'}"`,
      `"${m.status === 'active' ? 'نشط' : 'موقوف'}"`,
      `"${m.createdAt.toLocaleDateString('ar-EG')}"`
    ]);
    
    // Add UTF-8 BOM so Excel displays Arabic cleanly without corrupted letters
    const bom = '\uFEFF';
    const csvContent = bom + [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
    
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', `tajer_merchants_export_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="app-container">
      <Sidebar />
      <main className="main-content" style={{ padding: '2rem', position: 'relative' }}>
        <header className="flex-between mb-4">
          <div>
            <h1 style={{ fontSize: '2.2rem', fontWeight: 800, marginBottom: '0.25rem' }}>إدارة التجار والمشتركين</h1>
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.95rem' }}>التحكم الكامل بالحسابات، الموظفين، والصلاحيات الاستثنائية</p>
          </div>
          <div style={{ display: 'flex', gap: '1rem' }}>
            <button className="btn btn-secondary" onClick={exportCSV} style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', borderColor: 'var(--accent-primary)', color: '#fff' }}>
              <Download size={18} />
              تصدير الإحصائيات (Excel CSV)
            </button>
            <button className="btn btn-primary" onClick={fetchMerchants}>تحديث القائمة</button>
          </div>
        </header>

        <div className="glass-panel" style={{ padding: '1.5rem', overflowX: 'auto', borderRadius: '16px', border: '1px solid rgba(255,255,255,0.08)' }}>
          {loading ? (
            <div className="flex-center" style={{ padding: '4rem', color: 'var(--text-secondary)', fontSize: '1.1rem' }}>
              جاري سحب بيانات التجار الحية من قواعد السحابة...
            </div>
          ) : merchants.length === 0 ? (
            <div className="flex-center" style={{ padding: '4rem', color: 'var(--text-secondary)' }}>
              لا يوجد حسابات تجار مسجلة في قاعدة البيانات حالياً.
            </div>
          ) : (
            <table className="data-table" style={{ width: '100%', borderCollapse: 'separate', borderSpacing: '0 0.5rem' }}>
              <thead>
                <tr style={{ color: 'var(--text-secondary)', textAlign: 'right', fontSize: '0.9rem' }}>
                  <th style={{ padding: '1rem' }}>اسم التاجر</th>
                  <th style={{ padding: '1rem' }}>البريد الإلكتروني</th>
                  <th style={{ padding: '1rem' }}>الباقة</th>
                  <th style={{ padding: '1rem' }}>الحالة</th>
                  <th style={{ padding: '1rem' }}>تاريخ الانضمام</th>
                  <th style={{ padding: '1rem', textAlign: 'center' }}>الإجراءات السريعة</th>
                </tr>
              </thead>
              <tbody>
                {merchants.map((merchant) => (
                  <tr key={merchant.id} className="animate-fade-in" style={{ background: 'rgba(255, 255, 255, 0.02)', transition: 'all 0.2s ease' }}>
                    <td style={{ padding: '1rem', fontWeight: 700, borderRadius: '0 12px 12px 0', color: '#fff' }}>{merchant.name}</td>
                    <td style={{ padding: '1rem', color: 'var(--text-secondary)' }} dir="ltr" align="right">{merchant.email}</td>
                    <td style={{ padding: '1rem' }}>
                      <span className={`badge ${merchant.plan === 'pro' ? 'badge-warning' : 'badge-success'}`} style={{ padding: '0.4rem 0.8rem', borderRadius: '8px', fontWeight: 700 }}>
                        {merchant.plan === 'pro' ? 'برو Pro 👑' : 'أساسي Free 🆓'}
                      </span>
                    </td>
                    <td style={{ padding: '1rem' }}>
                      <span className={`badge ${merchant.status === 'active' ? 'badge-success' : 'badge-danger'}`} style={{ padding: '0.4rem 0.8rem', borderRadius: '8px', fontWeight: 700 }}>
                        {merchant.status === 'active' ? 'نشط ✅' : 'موقوف 🚫'}
                      </span>
                    </td>
                    <td style={{ padding: '1rem', color: 'var(--text-secondary)', fontSize: '0.875rem' }}>
                      {merchant.createdAt.toLocaleDateString('ar-EG')}
                    </td>
                    <td style={{ padding: '1rem', borderRadius: '12px 0 0 12px' }}>
                      <div className="flex-center gap-3" style={{ justifyContent: 'center', display: 'flex' }}>
                        <button
                          title="عرض التفاصيل والموظفين والمبيعات"
                          onClick={() => openDetailsModal(merchant)}
                          style={{ background: 'rgba(59, 130, 246, 0.15)', border: 'none', cursor: 'pointer', color: '#3B82F6', padding: '0.5rem', borderRadius: '8px', display: 'flex', alignItems: 'center' }}
                        >
                          <Eye size={18} />
                        </button>
                        <button
                          title={merchant.plan === 'pro' ? "إلغاء هدية الـ Pro" : "إهداء ترقية VIP Pro مجاناً"}
                          onClick={() => toggleProSubscription(merchant)}
                          style={{ background: 'rgba(245, 158, 11, 0.15)', border: 'none', cursor: 'pointer', color: '#F59E0B', padding: '0.5rem', borderRadius: '8px', display: 'flex', alignItems: 'center' }}
                        >
                          <Award size={18} />
                        </button>
                        <button
                          title={merchant.status === 'active' ? 'إيقاف/تجميد الحساب' : 'تفعيل الحساب'}
                          onClick={() => toggleStatus(merchant.id, merchant.status)}
                          style={{ background: merchant.status === 'active' ? 'rgba(239, 68, 68, 0.15)' : 'rgba(16, 185, 129, 0.15)', border: 'none', cursor: 'pointer', color: merchant.status === 'active' ? '#EF4444' : '#10B981', padding: '0.5rem', borderRadius: '8px', display: 'flex', alignItems: 'center' }}
                        >
                          {merchant.status === 'active' ? <PowerOff size={18} /> : <Power size={18} />}
                        </button>
                        <button
                          title="حذف الحساب نهائياً"
                          onClick={() => deleteMerchant(merchant.id)}
                          style={{ background: 'rgba(255, 255, 255, 0.05)', border: '1px solid rgba(239, 68, 68, 0.3)', cursor: 'pointer', color: '#EF4444', padding: '0.5rem', borderRadius: '8px', display: 'flex', alignItems: 'center' }}
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

        {/* Deep Details Modal */}
        {selectedMerchant && (
          <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0, 0, 0, 0.75)', backdropFilter: 'blur(6px)', display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 9999, padding: '1rem' }}>
            <div className="glass-card animate-fade-in" style={{ width: '100%', maxWidth: '750px', background: '#131620', border: '1px solid rgba(255, 255, 255, 0.15)', borderRadius: '20px', padding: '2rem', maxHeight: '90vh', overflowY: 'auto', boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.8)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '1px solid rgba(255, 255, 255, 0.1)', paddingBottom: '1.25rem', marginBottom: '1.5rem' }}>
                <div>
                  <h2 style={{ fontSize: '1.6rem', fontWeight: 800, color: '#fff', display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                    🏪 {selectedMerchant.name}
                    <span className={`badge ${selectedMerchant.plan === 'pro' ? 'badge-warning' : 'badge-success'}`} style={{ fontSize: '0.8rem', padding: '0.25rem 0.6rem' }}>
                      {selectedMerchant.plan === 'pro' ? 'PRO VIP' : 'مجاني FREE'}
                    </span>
                  </h2>
                  <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', marginTop: '0.25rem' }}>ID: {selectedMerchant.id} | البريد: {selectedMerchant.email}</p>
                </div>
                <button onClick={() => setSelectedMerchant(null)} style={{ background: 'transparent', border: 'none', color: '#fff', cursor: 'pointer', padding: '0.5rem' }}>
                  <X size={24} />
                </button>
              </div>

              {loadingDetails ? (
                <div style={{ textAlign: 'center', padding: '3rem', color: 'var(--text-secondary)' }}>جاري جلب ملفات المبيعات والموظفين من السيرفر...</div>
              ) : (
                <>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '1rem', marginBottom: '2rem' }}>
                    <div style={{ background: 'rgba(255,255,255,0.03)', padding: '1.25rem', borderRadius: '14px', border: '1px solid rgba(255,255,255,0.06)', display: 'flex', alignItems: 'center', gap: '1rem' }}>
                      <ShoppingBag size={28} color="#3B82F6" />
                      <div>
                        <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', display: 'block' }}>إجمالي الفواتير الصادرة</span>
                        <strong style={{ fontSize: '1.5rem', color: '#fff' }}>{merchantSales.ordersCount} فاتورة</strong>
                      </div>
                    </div>
                    <div style={{ background: 'rgba(255,255,255,0.03)', padding: '1.25rem', borderRadius: '14px', border: '1px solid rgba(255,255,255,0.06)', display: 'flex', alignItems: 'center', gap: '1rem' }}>
                      <DollarSign size={28} color="#10B981" />
                      <div>
                        <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', display: 'block' }}>حجم التداول والمبيعات</span>
                        <strong style={{ fontSize: '1.5rem', color: '#10B981' }}>{merchantSales.totalRevenue} $</strong>
                      </div>
                    </div>
                  </div>

                  <h3 style={{ fontSize: '1.25rem', fontWeight: 800, color: '#fff', marginBottom: '1rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                    <UsersIcon size={20} color="var(--accent-primary)" />
                    موظفين التجر وصلاحياتهم ({merchantStaff.length})
                  </h3>

                  {merchantStaff.length === 0 ? (
                    <div style={{ background: 'rgba(255, 255, 255, 0.02)', padding: '1.5rem', borderRadius: '12px', textAlign: 'center', color: 'var(--text-secondary)', marginBottom: '1.5rem' }}>
                      لم يقم التاجر بإضافة موظفين أو كاشير حتى الآن. يدير المتجر بنفسه.
                    </div>
                  ) : (
                    <div style={{ marginBottom: '1.5rem', maxHeight: '220px', overflowY: 'auto', border: '1px solid rgba(255,255,255,0.06)', borderRadius: '12px' }}>
                      <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.9rem' }}>
                        <thead>
                          <tr style={{ background: 'rgba(255,255,255,0.04)', color: 'var(--text-secondary)' }}>
                            <th style={{ padding: '0.75rem', textAlign: 'right', borderBottom: '1px solid rgba(255,255,255,0.06)' }}>الاسم</th>
                            <th style={{ padding: '0.75rem', textAlign: 'right', borderBottom: '1px solid rgba(255,255,255,0.06)' }}>البريد / اليوزر</th>
                            <th style={{ padding: '0.75rem', textAlign: 'right', borderBottom: '1px solid rgba(255,255,255,0.06)' }}>الدور الصلاحي</th>
                          </tr>
                        </thead>
                        <tbody>
                          {merchantStaff.map(emp => (
                            <tr key={emp.id} style={{ borderBottom: '1px solid rgba(255,255,255,0.03)' }}>
                              <td style={{ padding: '0.75rem', fontWeight: 600, color: '#fff' }}>{emp.name || 'موظف كاشير'}</td>
                              <td style={{ padding: '0.75rem', color: 'var(--text-secondary)' }} dir="ltr">{emp.email}</td>
                              <td style={{ padding: '0.75rem' }}>
                                <span style={{ background: 'rgba(139, 92, 246, 0.15)', color: '#8B5CF6', padding: '0.2rem 0.6rem', borderRadius: '6px', fontSize: '0.8rem', fontWeight: 700 }}>
                                  {emp.role === 'manager' ? 'مدير فرع 💼' : 'كاشير مبيعات 💻'}
                                </span>
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}

                  <div style={{ background: 'rgba(245, 158, 11, 0.08)', border: '1px solid rgba(245, 158, 11, 0.25)', borderRadius: '12px', padding: '1.25rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div>
                      <h4 style={{ color: '#F59E0B', fontWeight: 800, margin: 0, marginBottom: '0.35rem' }}>التحكم الاستثنائي بالباقة (VIP VIP Bypass)</h4>
                      <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem', margin: 0 }}>
                        يمكنك منح هذا التاجر وصولاً كاملاً لميزات PRO دون الدفع عبر Google Play، وسينعكس في جواله فوراً.
                      </p>
                    </div>
                    <button
                      onClick={() => toggleProSubscription(selectedMerchant)}
                      className="btn"
                      style={{ background: selectedMerchant.plan === 'pro' ? 'rgba(239, 68, 68, 0.2)' : '#F59E0B', color: selectedMerchant.plan === 'pro' ? '#EF4444' : '#000', fontWeight: 800, whiteSpace: 'nowrap', padding: '0.6rem 1.2rem' }}
                    >
                      {selectedMerchant.plan === 'pro' ? 'إلغاء الترقية' : 'تفعيل PRO مجاناً ⭐'}
                    </button>
                  </div>
                </>
              )}
            </div>
          </div>
        )}

      </main>
    </div>
  );
};

export default Users;
