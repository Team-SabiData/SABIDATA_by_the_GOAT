import { useEffect } from 'react';
import { BrowserRouter, Navigate, Route, Routes, useNavigate } from 'react-router-dom';
import { getToken, onUnauthorized } from './api';
import { ToastProvider } from './ui/Toast';
import { AppShell } from './AppShell';
import { Login } from './pages/Login';
import { Overview } from './pages/Overview';
import { Disputes } from './pages/Disputes';
import { Users } from './pages/Users';
import { Money } from './pages/Money';
import { Audit } from './pages/Audit';

function Guard({ children }: { children: React.ReactNode }) {
  const nav = useNavigate();
  useEffect(() => onUnauthorized(() => nav('/login')), [nav]);
  if (!getToken()) return <Navigate to="/login" replace />;
  return <>{children}</>;
}

export default function App() {
  return (
    <ToastProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route element={<Guard><AppShell /></Guard>}>
            <Route path="/" element={<Overview />} />
            <Route path="/disputes" element={<Disputes />} />
            <Route path="/users" element={<Users />} />
            <Route path="/money" element={<Money />} />
            <Route path="/audit" element={<Audit />} />
          </Route>
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </ToastProvider>
  );
}
