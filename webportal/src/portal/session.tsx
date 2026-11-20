import {Session} from "./useSession";
import {
  useEffect,
  useState,
  type ReactNode,
} from "react";
import { onIdTokenChanged, type User } from "firebase/auth";
import { doc, onSnapshot } from "firebase/firestore";
import { auth, db } from "@/config/firebase";
export function SessionProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState({
    user: null as User | null,
    level: 0,
    loading: true,
  });
  useEffect(() => {
    let stop = () => {};
    const unsub = onIdTokenChanged(auth, (user) => {
      stop();
      setState({ user, level: user ? 1 : 0, loading: false });
      if (user)
        stop = onSnapshot(
          doc(db, "roles", user.uid),
          (snap) => {
            const n = snap.data()?.level;
            setState({
              user,
              level: Number.isInteger(n) && n >= 1 && n <= 5 ? n : 1,
              loading: false,
            });
          },
          () => setState({ user, level: 1, loading: false }),
        );
    });
    return () => {
      stop();
      unsub();
    };
  }, []);
  return <Session.Provider value={state}>{children}</Session.Provider>;
}

