import { useState, useEffect } from 'react';
import Sidebar from '../components/Sidebar';
import { db } from '../firebase';
import { collection, getDocs, doc, setDoc, updateDoc } from 'firebase/firestore';
import { CreditCard, Edit3, Save, X } from 'lucide-react';

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
        // Create default plans if none exist
        const defaultPlans = [
          { id: 'free', name: 'الباقة المجانية', price: 0, duration: 'شهر', features: 'الميزات الأساسية', isPopular: false },
          { id: 'pro', name: 'باقة برو (Pro)', price: 10, duration: 'شهر', features: 'إدارة مخزون, مصاريف, تقارير', isPopular: true }
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
    } catch (error) {
      alert('حدث خطأ أثناء حفظ التعديلات');
    }
  };

  return (
    <div className="app-container">
      <Sidebar />
      <main className="main-content">
        <header className="flex-between mb-4">
          <h1 style={{ fontSize: '2rem', fontWeight: 800 }}>إدارة خطط الأسعار والاشتراكات</h1>
        </header>

        <p style={{ color: 'var(--text-secondary)', marginBottom: '2rem' }}>
          هنا يمكنك التحكم في أسعار الاشتراكات والميزات التي يحصل عليها التاجر في كل باقة. سيتم عكس هذه الأسعار مباشرة داخل التطبيق.
        </p>

        {loading ? (
          <div className="flex-center" style={{ padding: '2rem' }}>جاري التحميل...</div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '1.5rem' }}>
            {plans.map((plan) => (
              <div key={plan.id} className="glass-panel" style={{ padding: '2rem', position: 'relative' }}>
                {plan.isPopular && (
                  <span className="badge badge-warning" style={{ position: 'absolute', top: '-10px', right: '20px' }}>الأكثر طلباً</span>
                )}
                
                {editingId === plan.id ? (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                    <div>
                      <label style={{ color: 'var(--text-secondary)', fontSize: '0.875rem' }}>اسم الباقة</label>
                      <input 
                        type="text" 
                        className="input-field" 
                        value={editForm.name} 
                        onChange={(e) => setEditForm({...editForm, name: e.target.value})}
                      />
                    </div>
                    <div style={{ display: 'flex', gap: '1rem' }}>
                      <div style={{ flex: 1 }}>
                        <label style={{ color: 'var(--text-secondary)', fontSize: '0.875rem' }}>السعر ($)</label>
                        <input 
                          type="number" 
                          className="input-field" 
                          value={editForm.price} 
                          onChange={(e) => setEditForm({...editForm, price: e.target.value})}
                          dir="ltr"
                        />
                      </div>
                      <div style={{ flex: 1 }}>
                        <label style={{ color: 'var(--text-secondary)', fontSize: '0.875rem' }}>المدة</label>
                        <input 
                          type="text" 
                          className="input-field" 
                          value={editForm.duration} 
                          onChange={(e) => setEditForm({...editForm, duration: e.target.value})}
                        />
                      </div>
                    </div>
                    <div>
                      <label style={{ color: 'var(--text-secondary)', fontSize: '0.875rem' }}>الميزات (مفصولة بفاصلة)</label>
                      <textarea 
                        className="input-field" 
                        value={editForm.features} 
                        onChange={(e) => setEditForm({...editForm, features: e.target.value})}
                        rows="3"
                      />
                    </div>
                    <div className="flex-between mt-4">
                      <button className="btn btn-secondary" onClick={cancelEdit}><X size={18} className="ml-2"/> إلغاء</button>
                      <button className="btn btn-primary" onClick={() => handleSave(plan.id)}><Save size={18} className="ml-2"/> حفظ</button>
                    </div>
                  </div>
                ) : (
                  <>
                    <div className="flex-between mb-4">
                      <h2 style={{ fontSize: '1.5rem', fontWeight: 800 }} className="text-gradient">{plan.name}</h2>
                      <button onClick={() => startEdit(plan)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-secondary)' }}>
                        <Edit3 size={20} />
                      </button>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'baseline', gap: '0.25rem', marginBottom: '1.5rem' }}>
                      <span style={{ fontSize: '2.5rem', fontWeight: 800 }}>${plan.price}</span>
                      <span style={{ color: 'var(--text-secondary)' }}>/ {plan.duration}</span>
                    </div>
                    
                    <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
                      {plan.features.split(',').map((feature, idx) => (
                        <li key={idx} style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                          <CreditCard size={16} color="var(--accent-primary)" />
                          <span>{feature.trim()}</span>
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
