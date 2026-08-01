import { useState, useEffect } from 'react';
import Sidebar from '../components/Sidebar';
import { db } from '../firebase';
import { collection, getDocs, doc, setDoc, updateDoc } from 'firebase/firestore';
import { CreditCard, Edit3, Save, X, CheckCircle2, RefreshCw, ShieldCheck } from 'lucide-react';

const Plans = () => {
  const [plans, setPlans] = useState([]);
  const [loading, setLoading] = useState(true);
  const [editingId, setEditingId] = useState(null);
  const [editForm, setEditForm] = useState({});

  useEffect(() => {
    fetchPlans();
  }, []);

  const fetchPlans = async () => {
    setLoading(true);
    try {
      const querySnapshot = await getDocs(collection(db, 'subscription_plans'));
      if (querySnapshot.empty) {
        // Create default plans matching RevenueCat & POS capabilities
        const defaultPlans = [
          { id: 'free', name: 'الباقة المجانية (Free)', price: 0, duration: 'مدى الحياة', features: 'إصدار الفواتير والطلب السريع, إدارة الأصناف الأساسية, دعم فني مجاني', isPopular: false },
          { id: 'pro', name: 'باقة برو الملكية (PRO)', price: 15, duration: 'شهر / سنوي عبر متجر جوجل', features: 'إدارة لا محدودة للموظفين والكاشير, نظام الورديات التقني (Shift Shield), تقارير الأرباح الشاملة PDF, مزامنة سحابية حية وتلقائية, خلو كامل من الإعلانات, دعم VIP مخصص', isPopular: true }
        ];
        
        for (const plan of defaultPlans) {
          await setDoc(doc(db, 'subscription_plans', plan.id), plan);
        }
        setPlans(defaultPlans);
      } else {
        const plansList = querySnapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data()
        }));
        setPlans(plansList);
      }
    } catch (error) {
      console.error("Error fetching plans:", error);
    } finally {
      setLoading(false);
    }
  };

  const startEdit = (plan) => {
    setEditingId(plan.id);
    setEditForm(plan);
  };

  const cancelEdit = () => {
    setEditingId(null);
    setEditForm({});
  };

  const handleSave = async (id) => {
    try {
      const planRef = doc(db, 'subscription_plans', id);
      await updateDoc(planRef, {
        name: editForm.name,
        price: Number(editForm.price),
        duration: editForm.duration,
        features: editForm.features
      });
      
      setPlans(plans.map(p => p.id === id ? editForm : p));
      setEditingId(null);
      alert('تم حفظ البيانات وتحديث إشعار الباقات بنجاح!');
    } catch (error) {
      alert('حدث خطأ أثناء حفظ التعديلات');
    }
  };

  return (
    <div className="app-container">
      <Sidebar />
      <main className="main-content" style={{ padding: '2rem' }}>
        <header className="flex-between mb-4">
          <div>
            <h1 style={{ fontSize: '2.2rem', fontWeight: 800, marginBottom: '0.25rem' }}>إدارة خطط الأسعار والاشتراكات</h1>
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.95rem' }}>مراقبة تفاصيل الاشتراكات والتزامن السحابي مع RevenueCat و Google Play</p>
          </div>
          <button className="btn btn-primary" onClick={fetchPlans} style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <RefreshCw size={16} />
            تحديث الباقات
          </button>
        </header>

        <div style={{ background: 'rgba(59, 130, 246, 0.1)', border: '1px solid rgba(59, 130, 246, 0.25)', borderRadius: '14px', padding: '1.25rem', marginBottom: '2.5rem', display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <ShieldCheck size={32} color="#3B82F6" />
          <div>
            <h4 style={{ color: '#3B82F6', fontWeight: 800, margin: 0, marginBottom: '0.3rem', fontSize: '1.05rem' }}>التكامل الذكي مع RevenueCat & Google Play Console</h4>
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', margin: 0 }}>
              الأسعار والشعار أدناه توضيحية للإحصاء داخل اللوحة. الدفع الفعلي والتحويل لمستحقاتك البنكية يتم بأعلى معايير الأمان العالمية مباشرة عبر **RevenueCat و Google Play**. يمكنك استثناء أي تاجر ومنحه صلاحية PRO مجاناً من شاشة (إدارة التجار).
            </p>
          </div>
        </div>

        {loading ? (
          <div className="flex-center" style={{ padding: '4rem', color: 'var(--text-secondary)' }}>جاري تحميل هياكل خطط الاشتراك...</div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))', gap: '2rem' }}>
            {plans.map((plan) => (
              <div key={plan.id} className="glass-panel" style={{ padding: '2.5rem', position: 'relative', borderRadius: '20px', border: plan.isPopular ? '2px solid rgba(245, 158, 11, 0.5)' : '1px solid rgba(255, 255, 255, 0.08)', background: plan.isPopular ? 'linear-gradient(180deg, rgba(245, 158, 11, 0.05) 0%, rgba(20, 24, 34, 0.7) 100%)' : 'rgba(255, 255, 255, 0.02)' }}>
                {plan.isPopular && (
                  <span className="badge badge-warning" style={{ position: 'absolute', top: '-14px', right: '28px', padding: '0.4rem 1rem', fontSize: '0.85rem', fontWeight: 800, boxShadow: '0 4px 12px rgba(245, 158, 11, 0.4)' }}>👑 الباقة الملكية الأكثر طلباً</span>
                )}
                
                {editingId === plan.id ? (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
                    <div>
                      <label style={{ color: 'var(--text-secondary)', fontSize: '0.875rem', display: 'block', marginBottom: '0.35rem' }}>اسم الباقة</label>
                      <input 
                        type="text" 
                        className="input-field" 
                        style={{ width: '100%' }}
                        value={editForm.name} 
                        onChange={(e) => setEditForm({...editForm, name: e.target.value})}
                      />
                    </div>
                    <div style={{ display: 'flex', gap: '1rem' }}>
                      <div style={{ flex: 1 }}>
                        <label style={{ color: 'var(--text-secondary)', fontSize: '0.875rem', display: 'block', marginBottom: '0.35rem' }}>السعر ($)</label>
                        <input 
                          type="number" 
                          className="input-field" 
                          style={{ width: '100%' }}
                          value={editForm.price} 
                          onChange={(e) => setEditForm({...editForm, price: e.target.value})}
                          dir="ltr"
                        />
                      </div>
                      <div style={{ flex: 1 }}>
                        <label style={{ color: 'var(--text-secondary)', fontSize: '0.875rem', display: 'block', marginBottom: '0.35rem' }}>المدة</label>
                        <input 
                          type="text" 
                          className="input-field" 
                          style={{ width: '100%' }}
                          value={editForm.duration} 
                          onChange={(e) => setEditForm({...editForm, duration: e.target.value})}
                        />
                      </div>
                    </div>
                    <div>
                      <label style={{ color: 'var(--text-secondary)', fontSize: '0.875rem', display: 'block', marginBottom: '0.35rem' }}>الميزات (مفصولة بفاصلة)</label>
                      <textarea 
                        className="input-field" 
                        value={editForm.features} 
                        onChange={(e) => setEditForm({...editForm, features: e.target.value})}
                        rows="5"
                        style={{ width: '100%', lineHeight: '1.6' }}
                      />
                    </div>
                    <div className="flex-between mt-4" style={{ display: 'flex', justifyContent: 'space-between', gap: '1rem' }}>
                      <button className="btn btn-secondary" onClick={cancelEdit} style={{ flex: 1 }}><X size={18} className="ml-2"/> إلغاء</button>
                      <button className="btn btn-primary" onClick={() => handleSave(plan.id)} style={{ flex: 1 }}><Save size={18} className="ml-2"/> حفظ</button>
                    </div>
                  </div>
                ) : (
                  <>
                    <div className="flex-between mb-4" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <h2 style={{ fontSize: '1.65rem', fontWeight: 800, color: '#fff' }}>{plan.name}</h2>
                      <button onClick={() => startEdit(plan)} style={{ background: 'rgba(255,255,255,0.05)', padding: '0.5rem', borderRadius: '8px', border: 'none', cursor: 'pointer', color: 'var(--text-secondary)' }}>
                        <Edit3 size={20} />
                      </button>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'baseline', gap: '0.4rem', marginBottom: '2rem', borderBottom: '1px solid rgba(255,255,255,0.08)', paddingBottom: '1.5rem' }}>
                      <span style={{ fontSize: '3rem', fontWeight: 800, color: plan.isPopular ? '#F59E0B' : '#10B981' }}>${plan.price}</span>
                      <span style={{ color: 'var(--text-secondary)', fontSize: '1.1rem' }}>/ {plan.duration}</span>
                    </div>
                    
                    <h5 style={{ color: '#fff', fontSize: '1rem', marginBottom: '1rem', fontWeight: 700 }}>أبرز ميزات الباقة:</h5>
                    <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                      {plan.features.split(',').map((feature, idx) => (
                        <li key={idx} style={{ display: 'flex', alignItems: 'flex-start', gap: '0.75rem', lineHeight: '1.5' }}>
                          <CheckCircle2 size={20} color={plan.isPopular ? '#F59E0B' : '#10B981'} style={{ flexShrink: 0, marginTop: '2px' }} />
                          <span style={{ color: 'var(--text-secondary)', fontSize: '0.95rem' }}>{feature.trim()}</span>
                        </li>
                      ))}
                    </ul>
                  </>
                )}
              </div>
            ))}
          </div>
        )}
      </main>
    </div>
  );
};

export default Plans;

