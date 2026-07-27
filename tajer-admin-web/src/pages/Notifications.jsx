import { useState, useEffect } from 'react';
import Sidebar from '../components/Sidebar';
import { db } from '../firebase';
import { collection, addDoc, getDocs, serverTimestamp } from 'firebase/firestore';
import { Bell, Send } from 'lucide-react';

const Notifications = () => {
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [targetAudience, setTargetAudience] = useState('all');
  const [sending, setSending] = useState(false);
  const [success, setSuccess] = useState(false);
  
  const [merchants, setMerchants] = useState([]);

  useEffect(() => {
    fetchMerchants();
  }, []);

  const fetchMerchants = async () => {
    const snapshot = await getDocs(collection(db, 'merchants'));
    const list = [];
    snapshot.forEach(doc => {
      list.push({ id: doc.id, ...doc.data() });
    });
    setMerchants(list);
  };

  const handleSend = async (e) => {
    e.preventDefault();
    if (!title || !message) return;
    
    setSending(true);
    setSuccess(false);

    try {
      // Determine which merchants get the notification
      let targetMerchants = merchants;
      if (targetAudience === 'active') {
        targetMerchants = merchants.filter(m => m.status === 'active');
      } else if (targetAudience === 'pro') {
        targetMerchants = merchants.filter(m => m.subscriptionPlan === 'pro');
      }

      // Send to each target merchant
      for (const merchant of targetMerchants) {
        await addDoc(collection(db, `users/${merchant.id}/notifications`), {
          title,
          message,
          createdAt: serverTimestamp(),
          isRead: false
        });
      }

      setSuccess(true);
      setTitle('');
      setMessage('');
      setTimeout(() => setSuccess(false), 3000);
    } catch (error) {
      console.error("Error sending notification:", error);
      alert("حدث خطأ أثناء إرسال الإشعار");
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="app-container">
      <Sidebar />
      <main className="main-content">
        <header className="flex-between mb-4">
          <h1 style={{ fontSize: '2rem', fontWeight: 800 }}>إرسال الإشعارات</h1>
        </header>

        <div className="glass-card" style={{ padding: '2rem', maxWidth: '800px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', marginBottom: '2rem' }}>
            <div style={{ padding: '1rem', borderRadius: '12px', background: 'rgba(59, 130, 246, 0.1)', color: '#3B82F6' }}>
              <Bell size={24} />
            </div>
            <div>
              <h2 style={{ fontSize: '1.25rem', fontWeight: 700 }}>إشعار جديد</h2>
              <p style={{ color: 'var(--text-secondary)' }}>سيتم إرسال هذا الإشعار ليظهر داخل تطبيق التجار مباشرة</p>
            </div>
          </div>

          <form onSubmit={handleSend}>
            <div style={{ marginBottom: '1.5rem' }}>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: 600 }}>الفئة المستهدفة</label>
              <select 
                value={targetAudience}
                onChange={(e) => setTargetAudience(e.target.value)}
                style={{
                  width: '100%',
                  padding: '1rem',
                  borderRadius: '12px',
                  background: 'rgba(255, 255, 255, 0.05)',
                  border: '1px solid rgba(255, 255, 255, 0.1)',
                  color: 'white',
                  outline: 'none'
                }}
              >
                <option value="all" style={{ color: 'black' }}>الجميع (كل التجار)</option>
                <option value="active" style={{ color: 'black' }}>التجار النشطين فقط</option>
                <option value="pro" style={{ color: 'black' }}>مشتركي الخطة الاحترافية فقط</option>
              </select>
            </div>

            <div style={{ marginBottom: '1.5rem' }}>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: 600 }}>عنوان الإشعار</label>
              <input 
                type="text" 
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="مثال: تحديث جديد للنظام!"
                required
                style={{
                  width: '100%',
                  padding: '1rem',
                  borderRadius: '12px',
                  background: 'rgba(255, 255, 255, 0.05)',
                  border: '1px solid rgba(255, 255, 255, 0.1)',
                  color: 'white',
                  outline: 'none'
                }}
              />
            </div>

            <div style={{ marginBottom: '2rem' }}>
              <label style={{ display: 'block', marginBottom: '0.5rem', fontWeight: 600 }}>محتوى الإشعار</label>
              <textarea 
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                placeholder="اكتب رسالتك هنا..."
                required
                rows={4}
                style={{
                  width: '100%',
                  padding: '1rem',
                  borderRadius: '12px',
                  background: 'rgba(255, 255, 255, 0.05)',
                  border: '1px solid rgba(255, 255, 255, 0.1)',
                  color: 'white',
                  outline: 'none',
                  resize: 'vertical'
                }}
              />
            </div>

            {success && (
              <div style={{ padding: '1rem', background: 'rgba(16, 185, 129, 0.1)', color: '#10B981', borderRadius: '12px', marginBottom: '1.5rem', textAlign: 'center' }}>
                تم إرسال الإشعار بنجاح!
              </div>
            )}

            <button 
              type="submit" 
              disabled={sending}
              style={{
                width: '100%',
                padding: '1rem',
                borderRadius: '12px',
                background: sending ? '#6B7280' : 'var(--primary)',
                color: 'white',
                border: 'none',
                fontWeight: 'bold',
                cursor: sending ? 'not-allowed' : 'pointer',
                display: 'flex',
                justifyContent: 'center',
                alignItems: 'center',
                gap: '0.5rem',
                fontSize: '1.1rem'
              }}
            >
              {sending ? 'جاري الإرسال...' : (
                <>
                  <Send size={20} />
                  إرسال الآن
                </>
              )}
            </button>
          </form>
        </div>
      </main>
    </div>
  );
};

export default Notifications;
